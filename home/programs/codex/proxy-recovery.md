## Proxy recovery

After normal retries are exhausted, if a connection expected to use a proxy
still fails with a connection or proxy egress error, report the exact error,
attempt count, and blocked operation. Ask the user to switch proxy nodes, then
continue the blocked operation. A node switch is a recovery suggestion, not a
proven root cause. Handle clear authentication, permission, service, or account
quota failures according to their actual cause.
