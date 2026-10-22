// SPDX-License-Identifier: GPL-2.0
/*
 * q28peek — dump the DSI host link/latch state of a live Q28 bad boot.
 * Offsets come from pahole on the matching vmlinux. Diagnostic only.
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/clk.h>

static unsigned long glb;
module_param(glb, ulong, 0444);

/* struct msm_dsi: host@16, id@60 ; struct msm_dsi_host: base@0, id@48 */
#define MSM_DSI_HOST_OFF	16
#define MH_ID_OFF		48
#define MH_BYTE_SRC		184
#define MH_PIXEL_SRC		192
#define MH_PLL_BYTE		200
#define MH_PLL_PIXEL		208
#define MH_BYTE_RATE		232
#define MH_INTF_RATE		240
#define MH_PIXEL_RATE		256
#define MH_LINK_BYTE		272
#define MH_LINK_PIXEL		280
#define MH_LINK_INTF		288
#define MH_LINK_CFG		296
#define MH_POWER_ON		621

static int __init q28peek_init(void)
{
	void **dsi = (void **)(uintptr_t)glb;
	int i, cnt;
	u8 *mh;

	if (!glb) { pr_err("q28peek: glb= not given\n"); return -EINVAL; }
	cnt = (int)(unsigned long)*(void **)((uintptr_t)glb + 32); /* heuristic fallback */
	pr_info("q28peek: glb=%px\n", dsi);
	for (i = 0; i < 2; i++) {
		void *d = READ_ONCE(dsi[i]);
		if (!d) { pr_info("q28peek: dsi[%d]=NULL\n", i); continue; }
		mh = *(void **)((u8 *)d + MSM_DSI_HOST_OFF);
		if (!mh) { pr_info("q28peek: dsi[%d] host=NULL\n", i); continue; }
		pr_info("q28peek: dsi[%d]=%px id=%d host=%px\n", i, d,
			*(int *)((u8 *)d + MH_ID_OFF - MSM_DSI_HOST_OFF + 0), mh);
		pr_info("  power_on=%u link_configured=%u\n",
			READ_ONCE(*(u8 *)(mh + MH_POWER_ON)),
			READ_ONCE(*(u8 *)(mh + MH_LINK_CFG)));
		pr_info("  byte  clk=%lu link=%lu %s\n",
			READ_ONCE(*(unsigned long *)(mh + MH_BYTE_RATE)),
			READ_ONCE(*(unsigned long *)(mh + MH_LINK_BYTE)),
			READ_ONCE(*(unsigned long *)(mh + MH_BYTE_RATE)) ==
			READ_ONCE(*(unsigned long *)(mh + MH_LINK_BYTE)) ? "OK" : "MISMATCH");
		pr_info("  pixel clk=%lu link=%lu %s\n",
			READ_ONCE(*(unsigned long *)(mh + MH_PIXEL_RATE)),
			READ_ONCE(*(unsigned long *)(mh + MH_LINK_PIXEL)),
			READ_ONCE(*(unsigned long *)(mh + MH_PIXEL_RATE)) ==
			READ_ONCE(*(unsigned long *)(mh + MH_LINK_PIXEL)) ? "OK" : "MISMATCH");
		pr_info("  intf  clk=%lu link=%lu %s\n",
			READ_ONCE(*(unsigned long *)(mh + MH_INTF_RATE)),
			READ_ONCE(*(unsigned long *)(mh + MH_LINK_INTF)),
			READ_ONCE(*(unsigned long *)(mh + MH_INTF_RATE)) ==
			READ_ONCE(*(unsigned long *)(mh + MH_LINK_INTF)) ? "OK" : "MISMATCH");
		{
			struct clk *bs = READ_ONCE(*(struct clk **)(mh + MH_BYTE_SRC));
			struct clk *ps = READ_ONCE(*(struct clk **)(mh + MH_PIXEL_SRC));
			pr_info("  byte_src=%px parent=%px pll_byte=%px\n", bs,
				bs ? clk_get_parent(bs) : NULL,
				READ_ONCE(*(struct clk **)(mh + MH_PLL_BYTE)));
			pr_info("  pixel_src=%px parent=%px pll_pixel=%px\n", ps,
				ps ? clk_get_parent(ps) : NULL,
				READ_ONCE(*(struct clk **)(mh + MH_PLL_PIXEL)));
		}
	}
	return 0;
}
static void __exit q28peek_exit(void) {}
module_init(q28peek_init);
module_exit(q28peek_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Q28 DSI host state dump probe");
