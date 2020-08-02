#!/usr/bin/env python3

from aiogram import Bot, types
from aiogram.dispatcher import Dispatcher
from aiogram.utils import executor
from random import randint
from threading import Thread
import asyncio
import itertools
import os
import sys

if len(sys.argv) == 1:
    print('Usage: ')
    print('  TELEGRAM_TOKEN=xxx:yyyyy python3 %s ZMQ_ADDRESS' % sys.argv[0])
    print('Place Chat IDs you want to send notification')
    print(' in notify_chat_ids.lst, one ID per line.')
    exit()

PENDING_DURATION = 30
PENDING_MAX_SIZE = 20
LIST_MAX_SIZE = 30
TOKEN = os.environ['TELEGRAM_TOKEN']
ZMQ_CHANGES = sys.argv[1]

bot = Bot(token=TOKEN)

with open('chat_id.lst', 'r') as f:
    chat_ids = set([int(line) for line in f.readlines()])

with open('notify_chat_id.lst', 'r') as f:
    notify_chat_ids = set([int(line) for line in f.readlines()])

dp = Dispatcher(bot)

@dp.message_handler(commands=['start'])
async def send_welcome(message: types.Message):
    chat_id = int(message.chat.id)
    if chat_id in chat_ids:
        return
    chat_ids.add(int(message.chat.id))
    with open('chat_id.lst', 'w') as f:
        for i in chat_ids:
            f.write(str(i)+'\n')
    await message.reply("喵")

@dp.message_handler(commands=['stop'])
async def send_welcome(message: types.Message):
    chat_id = int(message.chat.id)
    if chat_id not in chat_ids:
        return
    chat_ids.remove(int(message.chat.id))
    with open('chat_id.lst', 'w') as f:
        for i in chat_ids:
            f.write(str(i)+'\n')
    await message.reply("发不出声音了")

@dp.message_handler(commands=['ping'])
async def send_echo(message: types.Message):
    await bot.send_chat_action(message.chat.id, action=types.ChatActions.TYPING)

import zmq
import zmq.asyncio
ctx = zmq.asyncio.Context.instance()
s = ctx.socket(zmq.SUB)
s.connect(ZMQ_CHANGES)
s.subscribe(b'')

def classify(pending_list: list):
    msg = ''
    def get_header(p):
        comp = p['comp']
        arch = p['arch']
        return f'<b>{comp}</b> {arch}\n'
    pending_list.sort(key=get_header)
    for header, g in itertools.groupby(pending_list, key=get_header):
        entries = list(g)
        msg += header
        preferred_order = ['delete', 'new', 'overwrite', 'upgrade']
        entries.sort(key=lambda x: (preferred_order.index(x['method']), x['pkg']))
        too_long = len(entries) > LIST_MAX_SIZE
        for p in entries if not too_long else entries[:LIST_MAX_SIZE]:
            pkg = p['pkg']
            to_ver = p['to_ver']
            from_ver = p['from_ver']
            method = p['method']
            if method == 'upgrade':
                msg += f'<code> ^</code> <a href="https://packages.aosc.io/packages/{pkg}">{pkg}</a> <code>{from_ver}</code> ⇒ <code>{to_ver}</code>\n'
            if method == 'new':
                msg += f'<code> +</code> <a href="https://packages.aosc.io/packages/{pkg}">{pkg}</a> <code>{to_ver}</code>\n'
            if method == 'delete':
                msg += f'<code> -</code> <a href="https://packages.aosc.io/packages/{pkg}">{pkg}</a> <code>{from_ver}</code>\n'
            if method == 'overwrite':
                msg += f'<code> *</code> <a href="https://packages.aosc.io/packages/{pkg}">{pkg}</a> <code>{from_ver}</code>\n'
        if too_long:
            remain = len(entries) - LIST_MAX_SIZE
            msg += f'<i>and {remain} more...</i>\n'
        msg += '\n'
    print(msg)
    return msg[:-1]

async def co():
    pending_list = []
    while True:
        try:
            message = await asyncio.wait_for(s.recv_json(), timeout=PENDING_DURATION)
            print(message)
            pending_list.append(message)
            if len(pending_list) > PENDING_MAX_SIZE:
                raise asyncio.TimeoutError()
        except asyncio.TimeoutError:
            if len(pending_list) > 0:
                print('send', len(pending_list))
                for chat_id in notify_chat_ids:
                   await bot.send_message(chat_id, classify(pending_list),
                                          parse_mode='HTML',
                                          disable_web_page_preview=True)
                pending_list = []

asyncio.ensure_future(co(), loop=dp.loop)

if __name__ == '__main__':
    executor.start_polling(dp)

