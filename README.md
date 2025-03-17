**Windmill Power Script**

*Power up your FiveM server with some green energy vibes!*

**What’s it all about?**
Get ready to own windmills, generate electricity, and stack that cash! Perfect for economy or RP servers.

**Dependencies**

* ox_lib
* ox_inventory
* QBX Framework
* oxmysql

:key: **Cool Features:**

:house: **Buy Windmills:** Grab your own windmill and start your energy hustle!

:low_battery: **Generate Power:** Watch your windmill crank out electricity to sell.

:wrench: **Upgrade Like a Pro:** Boost your windmill with epic tech:

* Durability Upgrade :muscle: – Keeps it running longer.
* Storage Upgrade :package: – Stockpile more power.
* Efficiency Upgrade :rocket: – More juice, more profits!
* Security Upgrade :police_officer: - Save that energy!
* Grid Connection Upgrade :globe_with_meridians: - Sell the stuff instantly!

:moneybag: **Sell the Juice:** Turn your electricity into sweet in-game cash!

:gear: **Tweak It:** Customize rates and costs to fit your server’s style.

**Why You’ll Love It:**
:star2: Fresh business idea for your players to dive into.
:tada: Easy setup for any FiveM server.

**Sneak Peek ( ALREADY NEW STUFF ADDED ):**

![](https://img.youtube.com/vi/UK-iXH17SPo/maxresdefault.jpg "lsn-voltage | SELL YOUR OWN ENERGY!")

[lsn-voltage | SELL YOUR OWN ENERGY!](https://www.youtube.com/watch?v=UK-iXH17SPo)

**Ready to Go?**
Grab it now and let your players build their energy empires!

**Installation**

1. Place in the resources directory.

2. Add `ensure lsn-voltage` into the server.cfg ( Below every Dependencies! )

3. Import `import.sql` to the Database. 
This includes the table and the already BY DEFAULT existing Windmill. If u want to add them by yourself, remove the INSERT part line 11-51. 
Turn Config.Debug = true to get access to the /createwind Command to add new Windmills.

4. Edit `config.lua` to your liking

5. Add the following Item to ur `ox_inventory`

```lua
['battery'] = {
        label = 'Battery',
        weight = 50000,
        description = "A energy filled battery"
    },
```

5. Restart the server.
