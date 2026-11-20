Respond to Rob's review of v8: drop the private "port-select-gpios"
property and drive the shared High Speed data path through a mux
controller instead ("Use the gpio mux binding").

The connector to drive is still published per endpoint via "mux-state";
dwc3_role_mux_init() now requires the "mux-controls" property and gets
the controller with devm_mux_control_get().  A mux controller cannot be
read back, so the boot-time connector can no longer be detected: the
initial mode request claims the mux for state 0 instead, which is the
first mode request that reaches __dwc3_set_mode() after probe.

mux_control_select() sleeps while waiting for the controller, and
mux_control_deselect() may sleep as well.  Both are only ever called
from __dwc3_set_mode(), which runs as a work item on
system_freezable_wq; the role-switch set() callback keeps recording the
request and never touches the mux directly.  The mux is kept selected
between switches, since the controller always drives exactly one of the
two connectors.

This rework does not change the arbitration, the publication ordering
or the teardown rules introduced in v7/v8.

Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>

