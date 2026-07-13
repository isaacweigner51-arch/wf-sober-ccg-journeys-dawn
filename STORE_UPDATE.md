# Journey's Dawn Store Alpha

Added a working prototype card-pack economy:

- 5 Journey's Dawn packs for 200 Gold
- 5 Journey's Dawn packs for $2.99 (prototype/demo purchase callback)
- Persistent gold, pack inventory, and card collection using `user://journeys_dawn_profile.cfg`
- Store screen, currency bar, owned-pack counter, and pack-opening inventory consumption
- Starts with 600 Gold so the store can be tested immediately

The $2.99 button currently performs a clearly labeled demo purchase. Before a public mobile/desktop release, connect `buy_packs_cash_demo()` to the platform billing SDK and grant packs only after verified payment.
