// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * nproc_guard -- un-wedge a DroidVM app whose per-uid RLIMIT_NPROC ucounts
 * counter has drifted away from the truth, WITHOUT a reboot.
 *
 * Why this exists: DroidVM repeatedly switches a thread's *real* uid between
 * root and the app uid (crosvm drops privilege to the app uid to reach the
 * camera / mic / app-scoped files; the root daemon does the same for a
 * connection).  The kernel's NPROC ucounts accounting -- kernel/cred.c
 * commit_creds(), whose transfer is gated on the user_struct while the charge
 * lives on the ucounts -- can desync across those real-uid switches: the counter
 * ends up higher (a charge left behind when a thread hands the app uid back) or
 * lower (a thread charged to the app uid whose commit never incremented the
 * counter) than the number of tasks actually charged.  Once the counter is
 * negative -- or climbs past the app's RLIMIT_NPROC (57556 on these builds) --
 * kernel/fork.c's is_rlimit_overlimit() (val < 0 || val > max) fails EVERY fork
 * for that uid, so Zygote can no longer start the app and it "won't open" until
 * a reboot resets the counter.  The real fix is on the crosvm/daemon side (use
 * fs/effective-uid only, which never touches the real uid or NPROC); this module
 * is the no-reboot rescue for a device that already wedged.
 *
 * The counter for NPROC is a bare tally (the plain, non-refcounted
 * inc/dec_rlimit_ucounts), so it is safe to overwrite it with the true number of
 * tasks currently charged to that uid.  A negative counter is ALWAYS a bug, and
 * the correct value while the app is closed is 0.
 *
 * The app uid differs per device, so it is NOT hardcoded: the daemon passes it
 * at load time.  A bare `insmod nproc_guard.ko` (no uid=) leaves the module
 * INACTIVE -- it must be loaded as:
 *
 *   insmod nproc_guard.ko uid=<app uid>        # daemon computes the uid
 *
 * Then, to un-wedge (from the daemon, or from Termux with root):
 *
 *   echo 1 > /sys/kernel/nproc_guard/reset     # recompute the configured uid
 *   cat /sys/kernel/nproc_guard/status         # what the last reset did
 *
 * alloc_ucounts / put_ucounts are not in the GKI module KMI; they are resolved
 * through a kprobe on kallsyms_lookup_name (same technique as udmabuf.ko).  One
 * source builds for GKI 6.1 / 6.6 / 6.12.
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

/*
 * The app uid to guard.  -1 (default) = INACTIVE: a bare insmod does nothing;
 * the daemon must load with uid=<app uid>.  Writable at runtime too, so the
 * daemon can (re)configure it via /sys/module/<name>/parameters/uid.
 */
static int uid = -1;
module_param(uid, int, 0644);
MODULE_PARM_DESC(uid,
	"app uid to guard; the daemon sets it at load (insmod nproc_guard.ko uid=<app uid>). -1 = inactive.");

/* ---- resolve unexported symbols via a kprobe on kallsyms_lookup_name ------ */
static unsigned long (*ng_lookup_name)(const char *name);
static struct ucounts *(*ng_alloc_ucounts)(struct user_namespace *ns, kuid_t kuid);
static void (*ng_put_ucounts)(struct ucounts *ucounts);

static void ng_resolve(void)
{
	struct kprobe kp = { .symbol_name = "kallsyms_lookup_name" };

	if (register_kprobe(&kp) < 0) {
		pr_warn("nproc_guard: kallsyms_lookup_name not probeable\n");
		return;
	}
	ng_lookup_name = (void *)kp.addr;
	unregister_kprobe(&kp);
	if (!ng_lookup_name)
		return;
	ng_alloc_ucounts = (void *)ng_lookup_name("alloc_ucounts");
	ng_put_ucounts	 = (void *)ng_lookup_name("put_ucounts");
}

/* last-reset bookkeeping for the status node */
static int	ng_last_uid = -1;
static long	ng_last_old, ng_last_new;

/*
 * Recompute uid @u's RLIMIT_NPROC counter to the number of tasks currently
 * charged to its ucounts.  Returns the old value, or LONG_MIN if unreachable.
 */
static long ng_fix_uid(uid_t u, long *new_out)
{
	kuid_t kuid = make_kuid(&init_user_ns, u);
	struct task_struct *p, *t;
	struct ucounts *uc;
	long charged = 0, old;

	if (!ng_alloc_ucounts || !ng_put_ucounts)
		return LONG_MIN;
	uc = ng_alloc_ucounts(&init_user_ns, kuid);
	if (!uc)
		return LONG_MIN;

	rcu_read_lock();
	for_each_process(p)
		for_each_thread(p, t)
			if (task_ucounts(t) == uc)
				charged++;
	rcu_read_unlock();

	old = atomic_long_read(&uc->rlimit[UCOUNT_RLIMIT_NPROC]);
	if (old != charged)
		atomic_long_set(&uc->rlimit[UCOUNT_RLIMIT_NPROC], charged);
	ng_put_ucounts(uc);

	*new_out = charged;
	return old;
}

/* Any write recomputes the *configured* uid; the written value is ignored. */
static ssize_t reset_store(struct kobject *kobj, struct kobj_attribute *attr,
			   const char *buf, size_t count)
{
	long old, new = 0;
	int u = READ_ONCE(uid);

	if (u < 0)
		return -ENODEV;	/* inactive: daemon never set the uid */

	old = ng_fix_uid((uid_t)u, &new);
	if (old == LONG_MIN)
		return -EIO;

	ng_last_uid = u;
	ng_last_old = old;
	ng_last_new = new;
	pr_info("nproc_guard: uid=%d RLIMIT_NPROC %ld -> %ld\n", u, old, new);
	return count;
}

static ssize_t reset_show(struct kobject *kobj, struct kobj_attribute *attr,
			  char *buf)
{
	if (READ_ONCE(uid) < 0)
		return sysfs_emit(buf,
			"INACTIVE: no uid configured. Load as: insmod nproc_guard.ko uid=<app uid>\n");
	return sysfs_emit(buf,
		"write any value here to recompute uid=%d's RLIMIT_NPROC counter to its true live count (un-wedge without reboot).\n",
		READ_ONCE(uid));
}

static ssize_t status_show(struct kobject *kobj, struct kobj_attribute *attr,
			   char *buf)
{
	int u = READ_ONCE(uid);

	if (u < 0)
		return sysfs_emit(buf, "state=inactive (no uid set); ucounts=%s\n",
				  ng_alloc_ucounts ? "ok" : "UNAVAILABLE");
	if (ng_last_uid < 0)
		return sysfs_emit(buf, "state=active uid=%d; ucounts=%s; no reset yet\n",
				  u, ng_alloc_ucounts ? "ok" : "UNAVAILABLE");
	return sysfs_emit(buf,
		"state=active uid=%d; ucounts=ok; last reset: uid=%d  %ld -> %ld%s\n",
		u, ng_last_uid, ng_last_old, ng_last_new,
		ng_last_old == ng_last_new ? " (already correct)" : "");
}

static struct kobj_attribute reset_attr = __ATTR(reset, 0644, reset_show, reset_store);
static struct kobj_attribute status_attr = __ATTR_RO(status);

static struct attribute *ng_attrs[] = {
	&reset_attr.attr,
	&status_attr.attr,
	NULL,
};
ATTRIBUTE_GROUPS(ng);

static struct kobject *ng_kobj;

static int __init ng_init(void)
{
	int ret;

	ng_resolve();
	ng_kobj = kobject_create_and_add("nproc_guard", kernel_kobj);
	if (!ng_kobj)
		return -ENOMEM;
	ret = sysfs_create_groups(ng_kobj, ng_groups);
	if (ret) {
		kobject_put(ng_kobj);
		ng_kobj = NULL;
		return ret;
	}
	pr_info("nproc_guard: /sys/kernel/nproc_guard ready (uid=%d%s, alloc_ucounts=%s)\n",
		uid, uid < 0 ? " INACTIVE" : "",
		ng_alloc_ucounts ? "ok" : "MISS");
	return 0;
}

static void __exit ng_exit(void)
{
	if (ng_kobj) {
		sysfs_remove_groups(ng_kobj, ng_groups);
		kobject_put(ng_kobj);
	}
}

module_init(ng_init);
module_exit(ng_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("DroidVM: recompute a wedged app uid's RLIMIT_NPROC ucounts counter (no-reboot rescue)");
MODULE_AUTHOR("DroidVM");
