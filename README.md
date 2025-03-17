# lsn-voltage

Script to own and upgrade a Windmill.

# Installation

1. Place in the resources directory.

2. Add `ensure lsn-voltage` into the server.cfg ( Below every Dependencies! )

3. Import `import.sql` to the Database. 
This includes the table and the already BY DEFAULT existing Windmill. If u want to add them by yourself, remove the INSERT part line 11-51. 
Turn Config.Debug = true to get access to the /createwind Command to add new Windmills.

4. Edit `config.lua` to your liking

5. Add the following Item to ur `ox_inventory`

['battery'] = {
        label = 'Battery',
        weight = 50000,
        description = "A energy filled battery"
    },

5. Restart the server.