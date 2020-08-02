Deploying
---------

### Create A Bot
Contact @BotFather to create a new bot, he will also create a token for accessing the bot.

### Find the ZeroMQ Interface Address
The address is placed in the configuration file of p-vector (or other compatible software)
It looks like `tcp://repo.aosc.io:xxxxx`.

### Launch the Bot
Install requirements:
```
pip3 install --user pyzmq aiogram
```

Start the bot:
```
TELEGRAM_TOKEN=12345:aB_cdEf_gfoobar python3 telegram.py tcp://repo.aosc.io:xxxxx
```

### Set the Chat IDs to Notify
1. Add the bot in your channels or groups (referred to as "chats" in Bot API terms).
2. Send a /start@... (bot's username) message.
3. Check the "chat_ids.lst" in current working directory, you will found the id of the chat.
4. Copy-and-paste the id to "notify_chat_ids.lst" file. If there is not, create one.

>> IDs of users are positive numbers, IDs of channels and groups are negative numbers.

Ctrl+C to stop the bot and restart it to apply the configuration.

### Additional Information

These debugging commands may be useful.

- `/start`
- `/stop`
- `/ping`

The general method to get the chat ID (instead of looking for "chat_ids.lst") is as follows:

1. Browse the URL https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   and you will see events the bot recently received.
2. Send some messages to the bot, refresh the "getUpdates" page mentioned
   at previous step, check if there is a new event.
3. Now you may add the bot to your chats and after refreshing the "getUpdates"
   you will see the IDs.

