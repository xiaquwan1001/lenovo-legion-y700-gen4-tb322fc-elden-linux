// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * nproc_probe -- TEMPORARY debug module for DroidVM.  Remove after debugging.
 *
 * Exposes the kernel's per-uid RLIMIT_NPROC ucounts counter -- the exact value
 * the fork path gates on:
 *
 *     kernel/fork.c:copy_process()
 *         if (is_rlimit_overlimit(task_ucounts(p), UCOUNT_RLIMIT_NPROC,
 *                                 rlimit(RLIMIT_NPROC)))   // -> -EAGAIN
 *     kernel/ucount.c:is_rlimit_overlimit()
 *         val = get_rlimit_value(iter, type)   // = atomic_long_read(rlimit[type])
 *
 * DroidVM's repeated root -> setuid(app uid) -> exec churn (one crosvm + one snd
 * vhost-user backend per VM, torn down and relaunched many times) drives this
 * counter for the app uid past the app's RLIMIT_NPROC (57556 on this build) and
 * it does not come back down -- so Zygote can no longer fork the app process and
 * "DroidVM won't open" until reboot, even though the uid then owns ZERO live
 * tasks.  This module lets us read the counter directly and watch it accumulate.
 *
 *   # default uid is 10355 (cn.classfun.droidvm on the test device)
 *   echo <uid> > /sys/kernel/nproc_probe/uid
 *   cat /sys/kernel/nproc_probe/nproc
 *   -> uid=10355 live_tasks=1 ucount_nproc=1 leaked=0 rlimit_cap=57556
 *
 *   live_tasks   tasks (threads) whose real uid == uid, counted right now.
 *   ucount_nproc the leaked kernel counter -- what fork() is judged against.
 *   leaked       ucount_nproc - live_tasks: dead-but-still-charged (should be 0;
 *                a growing value across VM start/stop cycles is the bug).
 *   rlimit_cap   the app-process RLIMIT_NPROC soft cap, for reference.
 *
 * It reads the counter even when the uid owns NO live task -- the exhausted
 * state where userspace cannot fork a probe at all -- by looking the ucounts up
 * in the kernel hashtable via alloc_ucounts().  Neither alloc_ucounts nor
 * put_ucounts is in the GKI 6.6 module KMI, so they are resolved through a
 * kprobe on kallsyms_lookup_name (same trick as udmabuf.ko in this tree).
 * Everything else (init_task, init_user_ns, kernel_kobj, sysfs) is in the KMI.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/kprobes.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>
#include <linux/cred.h>
#include <linux/uidgid.h>
#include <linux/user_namespace.h>
#include <linux/atomic.h>
#include <linux/rcupdate.h>
#include <linux/ptrace.h>

static int uid = 10355; /* cn.classfun.droidvm on the test device */
module_param(uid, int, 0644);
MODULE_PARM_DESC(uid,
	"app uid whose RLIMIT_NPROC ucounts counter to report (default 10355)");

static int trace = 1;
module_param(trace, int, 0644);
MODULE_PARM_DESC(trace,
	"kprobe dec_rlimit_ucounts and dump_stack when uid's NPROC counter crosses below 0 (default 1)");

/* ---- resolve unexported symbols via a kprobe on kallsyms_lookup_name ------ */
static unsigned long (*np_lookup_name)(const char *name);

static void np_resolve_lookup_name(void)
{
	struct kprobe kp = { .symbol_name = "kallsyms_lookup_name" };

	if (register_kprobe(&kp) < 0) {
		pr_warn("nproc_probe: kallsyms_lookup_name not probeable\n");
		return;
	}
	np_lookup_name = (void *)kp.addr;
	unregister_kprobe(&kp);
}

static struct ucounts *(*np_alloc_ucounts)(struct user_namespace *ns, kuid_t kuid);
static void (*np_put_ucounts)(struct ucounts *ucounts);

/*
 * The ucounts hashtable entry for uid u.  alloc_ucounts() returns the existing
 * entry with a ref taken, or creates a fresh (zero-counter) one if none exists.
 * Caller must np_put_ucounts() the result.  NULL if unreachable.
 */
static struct ucounts *np_get_uc(uid_t u)
{
	kuid_t kuid = make_kuid(&init_user_ns, u);

	if (!np_alloc_ucounts || !np_put_ucounts)
		return NULL;
	return np_alloc_ucounts(&init_user_ns, kuid);
}

/*
 * Walk every task and tally those the kernel actually charges to @uc, i.e.
 * task_ucounts(t) == uc (the exact key release_task() decrements).  This is the
 * ground truth to compare against the rlimit counter: any excess is a charge
 * with no task behind it (a genuine kernel accounting leak) rather than a task
 * my by-real-uid count happened to miss.  Also returns the by-real-uid live
 * count and the RLIMIT_NPROC soft cap, for context.
 */
static void np_tally(uid_t u, struct ucounts *uc, long *charged, long *live,
		     unsigned long *cap)
{
	struct task_struct *p, *t;

	*charged = 0;
	*live = 0;
	*cap = 0;
	rcu_read_lock();
	for_each_process(p) {
		for_each_thread(p, t) {
			if (uc && task_ucounts(t) == uc)
				(*charged)++;
			if (__kuid_val(__task_cred(t)->uid) == u) {
				(*live)++;
				if (!*cap)
					*cap = task_rlimit(t, RLIMIT_NPROC);
			}
		}
	}
	rcu_read_unlock();
}

static ssize_t nproc_show(struct kobject *kobj, struct kobj_attribute *attr,
			  char *buf)
{
	uid_t u = (uid_t)uid;
	struct ucounts *uc = np_get_uc(u);
	unsigned long cap = 0;
	long charged = 0, live = 0;
	long nproc = uc ? atomic_long_read(&uc->rlimit[UCOUNT_RLIMIT_NPROC]) : -1;

	np_tally(u, uc, &charged, &live, &cap);
	if (uc)
		np_put_ucounts(uc);

	/* charged  = tasks the kernel really charges to this ucounts (by pointer)
	 * kern_leak = nproc - charged: charge with NO task behind it -> real leak
	 * live      = tasks whose real uid == u (may differ from charged if any
	 *             task changed real uid without a matching charge move). */
	return sysfs_emit(buf,
		"uid=%u ucount_nproc=%ld charged_tasks=%ld live_tasks=%ld kern_leak=%ld rlimit_cap=%lu\n",
		u, nproc, charged, live,
		(nproc >= 0) ? nproc - charged : -1, cap);
}

/* /sys/kernel/nproc_probe/charged -- one line per task charged to this uid's
 * ucounts (task_ucounts == uc), so we can see WHAT holds the counter up. */
static ssize_t charged_show(struct kobject *kobj, struct kobj_attribute *attr,
			    char *buf)
{
	uid_t u = (uid_t)uid;
	struct ucounts *uc = np_get_uc(u);
	struct task_struct *p, *t;
	long counter;
	int len = 0;

	if (!uc)
		return sysfs_emit(buf, "uid=%u: ucounts unreachable\n", u);
	counter = atomic_long_read(&uc->rlimit[UCOUNT_RLIMIT_NPROC]);

	rcu_read_lock();
	for_each_process(p) {
		for_each_thread(p, t) {
			if (task_ucounts(t) != uc)
				continue;
			if (len >= PAGE_SIZE - 128) {
				len += scnprintf(buf + len, PAGE_SIZE - len,
						 "... (truncated)\n");
				goto done;
			}
			len += scnprintf(buf + len, PAGE_SIZE - len,
				"pid=%d tgid=%d ruid=%u euid=%u state=0x%x exit=0x%x ppid=%d comm=%s\n",
				t->pid, t->tgid,
				__kuid_val(__task_cred(t)->uid),
				__kuid_val(__task_cred(t)->euid),
				t->__state, t->exit_state,
				t->real_parent ? t->real_parent->pid : -1,
				t->comm);
		}
	}
done:
	rcu_read_unlock();
	np_put_ucounts(uc);
	if (len == 0)
		len = sysfs_emit(buf, "uid=%u: no task charged (counter=%ld is a pure leak)\n",
				 u, counter);
	return len;
}

/*
 * Recompute the RLIMIT_NPROC counter for this uid to the true number of tasks
 * currently charged to it, curing an underflow (negative counter -> every fork
 * EAGAIN -> app won't open) or a leak WITHOUT a reboot.  Safe because NPROC uses
 * the plain (non-refcounted) inc/dec_rlimit_ucounts, so the counter is a bare
 * tally not entangled with the ucounts refcount.  Do it while the uid is idle
 * (app closed) so the recomputed value (0) is exact and no fork races the set.
 */
static ssize_t reset_store(struct kobject *kobj, struct kobj_attribute *attr,
			   const char *buf, size_t count)
{
	uid_t u = (uid_t)uid;
	struct ucounts *uc = np_get_uc(u);
	struct task_struct *p, *t;
	long charged = 0, old;

	if (!uc)
		return -EIO;
	rcu_read_lock();
	for_each_process(p)
		for_each_thread(p, t)
			if (task_ucounts(t) == uc)
				charged++;
	rcu_read_unlock();
	old = atomic_long_read(&uc->rlimit[UCOUNT_RLIMIT_NPROC]);
	atomic_long_set(&uc->rlimit[UCOUNT_RLIMIT_NPROC], charged);
	np_put_ucounts(uc);
	pr_info("nproc_probe: reset uid=%u RLIMIT_NPROC %ld -> %ld (charged tasks)\n",
		u, old, charged);
	return count;
}

static ssize_t reset_show(struct kobject *kobj, struct kobj_attribute *attr,
			  char *buf)
{
	return sysfs_emit(buf,
		"write any value to set uid=%d RLIMIT_NPROC counter = live charged-task count (un-wedge without reboot; do it while the app is closed)\n",
		uid);
}

static ssize_t uid_show(struct kobject *kobj, struct kobj_attribute *attr,
			char *buf)
{
	return sysfs_emit(buf, "%d\n", uid);
}

static ssize_t uid_store(struct kobject *kobj, struct kobj_attribute *attr,
			 const char *buf, size_t count)
{
	int v, ret = kstrtoint(buf, 0, &v);

	if (ret)
		return ret;
	uid = v;
	return count;
}

/* defined below with the ring/kprobe machinery */
static ssize_t ctl_show(struct kobject *kobj, struct kobj_attribute *attr,
			char *buf);
static ssize_t ctl_store(struct kobject *kobj, struct kobj_attribute *attr,
			 const char *buf, size_t count);

static struct kobj_attribute nproc_attr = __ATTR_RO(nproc);
static struct kobj_attribute charged_attr = __ATTR_RO(charged);
static struct kobj_attribute reset_attr = __ATTR(reset, 0644, reset_show, reset_store);
static struct kobj_attribute uid_attr = __ATTR(uid, 0644, uid_show, uid_store);
static struct kobj_attribute ctl_attr = __ATTR(ctl, 0644, ctl_show, ctl_store);

static struct attribute *np_attrs[] = {
	&nproc_attr.attr,
	&charged_attr.attr,
	&reset_attr.attr,
	&uid_attr.attr,
	&ctl_attr.attr,
	NULL,
};
ATTRIBUTE_GROUPS(np);

static struct kobject *np_kobj;

/*
 * kprobe on dec_rlimit_ucounts(ucounts, type, v): the moment a decrement drives
 * uid's NPROC counter from >=0 to <0 -- the exact over-decrement that wedges the
 * app -- dump the stack.  The backtrace answers the whole question: if it runs
 * through one of our host modules, it's a host-mod bug; if it's a pure kernel
 * path (release_task/commit_creds/exit) with no module frames, it's the stock
 * kernel (mis)accounting for the daemon's setuid pattern.  Fires on the crossing
 * only (cur>=0 && cur-v<0), so at most once per underflow -- not a hot path.
 */
/*
 * Ring buffer of every inc/dec of uid's NPROC counter, so ONE app/VM cycle
 * reveals the imbalanced operation: an inc with no matching dec (the +1 leak) or
 * a dec from an unexpected caller (the over-dec).  Each event records the caller
 * (LR at function entry = the kernel site that called inc/dec_rlimit_ucounts),
 * printed with %pS.  "echo clear > ctl" resets; "echo dump > ctl" prints the ring
 * to the kernel log.
 */
struct np_ev {
	u8		kind;	/* 'I' inc, 'D' dec, 'M' commit_creds, 'R' release_task */
	u8		flags;	/* M: bit0 user_same, bit1 ns_same */
	u32		pid;
	long		a;	/* I/D: delta ; M: old_ruid ; R: dec_uid  */
	long		b;	/* I/D: post  ; M: new_ruid ; R: real_uid */
	u32		c;	/* M: old ucounts uid */
	u32		d;	/* M: new ucounts uid */
	unsigned long	caller;
	char		comm[TASK_COMM_LEN];
};
#define NP_RING 8192
static struct np_ev np_ring[NP_RING];
static atomic_t np_ring_idx = ATOMIC_INIT(0);

static void np_rec5(u8 kind, u8 flags, u32 pid, long a, long b, u32 c, u32 d,
		    unsigned long caller, const char *comm)
{
	unsigned int i = (atomic_inc_return(&np_ring_idx) - 1) & (NP_RING - 1);

	np_ring[i].kind = kind;
	np_ring[i].flags = flags;
	np_ring[i].pid = pid;
	np_ring[i].a = a;
	np_ring[i].b = b;
	np_ring[i].c = c;
	np_ring[i].d = d;
	np_ring[i].caller = caller;
	memcpy(np_ring[i].comm, comm, TASK_COMM_LEN);
}

static void np_rec(u8 kind, u32 pid, long a, long b, unsigned long caller,
		   const char *comm)
{
	np_rec5(kind, 0, pid, a, b, 0, 0, caller, comm);
}

/* true if this (ucounts,type) is uid's NPROC counter */
static bool np_is_target(struct ucounts *uc, long type)
{
	return uc && type == UCOUNT_RLIMIT_NPROC &&
	       __kuid_val(uc->uid) == (uid_t)uid;
}

static int np_inc_pre(struct kprobe *p, struct pt_regs *regs)
{
	struct ucounts *uc = (struct ucounts *)regs->regs[0];
	long type = (long)regs->regs[1];
	long v = (long)regs->regs[2];

	if (np_is_target(uc, type))
		np_rec('I', current->pid, +v,
		       atomic_long_read(&uc->rlimit[UCOUNT_RLIMIT_NPROC]) + v,
		       regs->regs[30], current->comm);
	return 0;
}

static int np_dec_pre(struct kprobe *p, struct pt_regs *regs)
{
	struct ucounts *uc = (struct ucounts *)regs->regs[0];
	long type = (long)regs->regs[1];
	long v = (long)regs->regs[2];
	long cur;

	if (!np_is_target(uc, type))
		return 0;
	cur = atomic_long_read(&uc->rlimit[UCOUNT_RLIMIT_NPROC]);
	np_rec('D', current->pid, -v, cur - v, regs->regs[30], current->comm);
	if (cur >= 0 && (cur - v) < 0) {
		pr_warn("nproc_probe: UNDERFLOW uid=%d NPROC %ld -%ld -> %ld  by pid=%d comm=%s\n",
			uid, cur, v, cur - v, current->pid, current->comm);
		dump_stack();
	}
	return 0;
}

/*
 * commit_creds(new): current is the task changing creds (valid pid).  Capture
 * exactly what decides the NPROC inc: the kernel's gate is
 *   if (new->user != old->user || new->user_ns != old->user_ns) inc(new->ucounts)
 * so when user_same && ns_same the inc is SKIPPED even though the real uid
 * changed -- that is how a task ends up charged to a uid whose counter never
 * incremented.  We record old/new real uid, old/new ucounts uid, and whether
 * user_struct / user_ns are unchanged, plus the caller (which syscall).
 */
static int np_commit_pre(struct kprobe *p, struct pt_regs *regs)
{
	struct cred *new = (struct cred *)regs->regs[0];
	const struct cred *old = current->real_cred;
	u32 ou, nu, ouc, nuc;
	u8 flags = 0;

	if (!new || !old || !old->ucounts || !new->ucounts)
		return 0;
	ou = __kuid_val(old->uid);
	nu = __kuid_val(new->uid);
	if (ou != (uid_t)uid && nu != (uid_t)uid)
		return 0;
	ouc = __kuid_val(old->ucounts->uid);
	nuc = __kuid_val(new->ucounts->uid);
	if (old->user == new->user)
		flags |= 1;	/* user_struct unchanged */
	if (old->user_ns == new->user_ns)
		flags |= 2;	/* user_ns unchanged */
	np_rec5('M', flags, current->pid, ou, nu, ouc, nuc, regs->regs[30],
		current->comm);
	return 0;
}

/* release_task(p): p is the dying task (valid pid); dec_uid = the ucounts its
 * exit will decrement, ruid = its real uid.  If a task with ruid==uid is reaped
 * with dec_uid!=uid, its NPROC charge leaks on uid. */
static int np_reap_pre(struct kprobe *p, struct pt_regs *regs)
{
	struct task_struct *t = (struct task_struct *)regs->regs[0];
	const struct cred *rc;
	u32 du, ru;

	if (!t)
		return 0;
	rc = t->real_cred;
	if (!rc || !rc->ucounts)
		return 0;
	du = __kuid_val(rc->ucounts->uid);
	ru = __kuid_val(rc->uid);
	if (du == (uid_t)uid || ru == (uid_t)uid)
		np_rec('R', t->pid, du, ru, regs->regs[30], t->comm);
	return 0;
}

static struct kprobe np_dec_kp = {
	.symbol_name = "dec_rlimit_ucounts",
	.pre_handler = np_dec_pre,
};
static struct kprobe np_inc_kp = {
	.symbol_name = "inc_rlimit_ucounts",
	.pre_handler = np_inc_pre,
};
static struct kprobe np_commit_kp = {
	.symbol_name = "commit_creds",
	.pre_handler = np_commit_pre,
};
static struct kprobe np_reap_kp = {
	.symbol_name = "release_task",
	.pre_handler = np_reap_pre,
};
static bool np_dec_kp_on, np_inc_kp_on, np_commit_kp_on, np_reap_kp_on;

static void np_dump_ring(void)
{
	int total = atomic_read(&np_ring_idx);
	int n = total < NP_RING ? total : NP_RING;
	int start = total < NP_RING ? 0 : (total & (NP_RING - 1));
	int k;

	pr_info("nproc_probe: ring dump uid=%d, %d event(s):\n", uid, n);
	for (k = 0; k < n; k++) {
		struct np_ev *e = &np_ring[(start + k) & (NP_RING - 1)];

		if (e->kind == 'M')
			pr_info("  [%4d] M commit ruid %u->%u ucounts %u->%u user_same=%d ns_same=%d NPROC_inc=%s pid=%-6u comm=%s by=%pS\n",
				k, (u32)e->a, (u32)e->b, e->c, e->d,
				!!(e->flags & 1), !!(e->flags & 2),
				((e->flags & 3) == 3) ? "SKIPPED" : "fires",
				e->pid, e->comm, (void *)e->caller);
		else if (e->kind == 'R')
			pr_info("  [%4d] R reap dec_uid=%u ruid=%u pid=%-6u comm=%s\n",
				k, (u32)e->a, (u32)e->b, e->pid, e->comm);
		else
			pr_info("  [%4d] %c %+ld -> %-4ld pid=%-6u comm=%-16s by=%pS\n",
				k, e->kind, e->a, e->b, e->pid, e->comm,
				(void *)e->caller);
	}
	pr_info("nproc_probe: ring dump end\n");
}

static ssize_t ctl_store(struct kobject *kobj, struct kobj_attribute *attr,
			 const char *buf, size_t count)
{
	if (sysfs_streq(buf, "clear"))
		atomic_set(&np_ring_idx, 0);
	else if (sysfs_streq(buf, "dump"))
		np_dump_ring();
	else
		return -EINVAL;
	return count;
}

static ssize_t ctl_show(struct kobject *kobj, struct kobj_attribute *attr,
			char *buf)
{
	return sysfs_emit(buf,
		"echo clear > ctl  (reset ring)\necho dump > ctl   (print ring to dmesg)\nrecorded=%d\n",
		atomic_read(&np_ring_idx));
}

static int __init np_init(void)
{
	int ret;

	np_resolve_lookup_name();
	if (np_lookup_name) {
		np_alloc_ucounts = (void *)np_lookup_name("alloc_ucounts");
		np_put_ucounts	 = (void *)np_lookup_name("put_ucounts");
	}

	np_kobj = kobject_create_and_add("nproc_probe", kernel_kobj);
	if (!np_kobj)
		return -ENOMEM;
	ret = sysfs_create_groups(np_kobj, np_groups);
	if (ret) {
		kobject_put(np_kobj);
		np_kobj = NULL;
		return ret;
	}

	if (trace) {
		np_dec_kp_on    = !register_kprobe(&np_dec_kp);
		np_inc_kp_on    = !register_kprobe(&np_inc_kp);
		np_commit_kp_on = !register_kprobe(&np_commit_kp);
		np_reap_kp_on   = !register_kprobe(&np_reap_kp);
	}

	pr_info("nproc_probe: /sys/kernel/nproc_probe ready (uid=%d, alloc_ucounts=%s put_ucounts=%s trace=%s%s%s%s)\n",
		uid, np_alloc_ucounts ? "ok" : "MISS",
		np_put_ucounts ? "ok" : "MISS",
		np_inc_kp_on ? "inc " : "", np_dec_kp_on ? "dec " : "",
		np_commit_kp_on ? "commit " : "", np_reap_kp_on ? "reap" : "");
	return 0;
}

static void __exit np_exit(void)
{
	if (np_reap_kp_on)
		unregister_kprobe(&np_reap_kp);
	if (np_commit_kp_on)
		unregister_kprobe(&np_commit_kp);
	if (np_inc_kp_on)
		unregister_kprobe(&np_inc_kp);
	if (np_dec_kp_on)
		unregister_kprobe(&np_dec_kp);
	if (np_kobj) {
		sysfs_remove_groups(np_kobj, np_groups);
		kobject_put(np_kobj);
	}
}

module_init(np_init);
module_exit(np_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("DroidVM debug: read per-uid RLIMIT_NPROC ucounts counter");
MODULE_AUTHOR("DroidVM");
