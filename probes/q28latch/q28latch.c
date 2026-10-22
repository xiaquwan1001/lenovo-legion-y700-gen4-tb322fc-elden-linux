// SPDX-License-Identifier: GPL-2.0
/*
 * q28latch — clear the one-way "bonded cmd failed" software latch at runtime
 * so that a Q28 bad boot can be probed without rebooting (which would destroy
 * the failure state).  Diagnostic only; never ship.
 *
 * dsi_manager.c keeps `static bool dsi_bonded_cmd_failed` and only ever sets
 * it.  Every later DSI transfer is then short-circuited with -EIO, which is
 * why panel re-init via DPMS off/on can never recover.
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/string.h>

static unsigned long addr;
module_param(addr, ulong, 0444);
MODULE_PARM_DESC(addr, "address of dsi_bonded_cmd_failed (from /proc/kallsyms)");
static int value = 0;
module_param(value, int, 0444);

static int __init q28latch_init(void)
{
	u8 *p, before, after;

	if (!addr) {
		pr_err("q28latch: addr= not given\n");
		return -EINVAL;
	}
	p = (u8 *)(uintptr_t)addr;
	before = READ_ONCE(*p);
	WRITE_ONCE(*p, (u8)value);
	after = READ_ONCE(*p);
	pr_info("q28latch: addr=%px before=%u wrote=%d after=%u\n",
		p, before, value, after);
	return 0;
}

static void __exit q28latch_exit(void)
{
	pr_info("q28latch: unloaded\n");
}

module_init(q28latch_init);
module_exit(q28latch_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Q28 bonded-cmd latch probe");
