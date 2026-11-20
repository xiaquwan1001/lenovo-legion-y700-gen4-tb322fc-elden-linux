usb_role_switch_get() and fwnode_usb_role_switch_get() look for a switch
on the caller's parent device node or through device_connection.  That does
not work when one controller exposes a role switch per connector endpoint:
the switch is registered against the remote graph endpoint and the
consumer, the connector, has no phandle to it.

Add usb_role_switch_at_endpoint(), which walks the caller's OF graph
endpoints and matches a switch registered on the remote endpoint, and try
it after the existing parent lookup.  A switch that is described by the
graph but not registered yet comes back as -EPROBE_DEFER, as the rest of
the role-switch API does, so the caller retries instead of concluding that
the connector has no role switch at all.  There is no behaviour change for
existing users: if nothing is registered against an endpoint the lookup
falls through to the previous paths.

This is needed by DWC3 designs where two Type-C receptacles share one High
Speed data bus.

Signed-off-by: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>
