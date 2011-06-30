Setup
=====

Requirements: Mail::IMAPClient, AppConfig

Customize the configuration variables at the beginning of the script.

HOST: your IMAP host
USER: your IMAP login (don't forget to escape the @)
PASSWORD: your IMAP password
TO: the mailbox read messages should be moved to
READLISTDIR: the directory where the list of seen messages should be stored

Operation
=========

When imapclean.pl is invoked, it goes through your INBOX. If a message is marked as read, and if that message was marked as read last time imapclean.pl was run, it moves the message to the mailbox specified in the configuration ("TO").

imapclean.pl also goes through the INBOX._zDone mailbox. It's treated like the INBOX, except that all messages are marked as read automatically (and thus are archived on the next run). On some mail clients (e.g. iPhone), it's easier to move messages to the _zDone folder than it is to open them and then go back to the message list. Moving them also gets them out of your face immediately instead of waiting for imapclean.pl to archive them.

Since imapclean.pl doesn't move messages until it sees them twice (so it doesn't move a message you just opened), figure out how long you want messages to stick around, and set it to run twice that often. For example, I want messages to sit in my inbox for 40 minutes after I've read them, so I run imapclean.pl every 20 minutes with a crontab entry like this:

    */20 * * * * /home/tamboli/bin/imapclean.pl

Caveats
=======

This was written pretty quickly, based mostly on the sample code in the Mail::IMAPClient manpage, so there are probably optimizations that can be made.

Please also note that imapclean.pl will expunge deleted messages, whether they were marked as deleted through imapclean.pl's actions or not.


Offered without warranty, as-is.