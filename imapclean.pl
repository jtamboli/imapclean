#!/usr/bin/perl -w

# die;

use strict;
use Mail::IMAPClient;
use IO::File;
use AppConfig qw/:argcount/;
use IO::Socket::SSL;
use POSIX qw(strftime);

my $config = AppConfig->new();

$config->define(
    'HOST' =>
      { ARGCOUNT => ARGCOUNT_ONE, DEFAULT => "mail.messagingengine.com" },
    'USER' => { ARGCOUNT => ARGCOUNT_ONE, DEFAULT => "USERNAME" },
    'PASSWORD' => { ARGCOUNT => ARGCOUNT_ONE, DEFAULT => "PASSWORD" },
    'TO'       => { ARGCOUNT => ARGCOUNT_ONE, DEFAULT => "INBOX.Archive" },
    'DUMP' => { ARGCOUNT => ARGCOUNT_NONE },
    'READLISTDIR' =>
      { ARGCOUNT => ARGCOUNT_ONE, DEFAULT => "/home/tamboli/" },
);

$config->args();

my @mailboxes = (
    "INBOX",
    "INBOX._zDone",
);
my $mailbox;
my @all_read_messages;

my $socket = IO::Socket::SSL->new(
    PeerAddr => $config->HOST(),
    PeerPort => 993,
) or die "socket(): $@";

# Build up a client attached to the SSL socket and login
# ----------------------------------------
my $imap = Mail::IMAPClient->new(
    Socket   => $socket,
    User     => $config->USER(),
    Password => $config->PASSWORD(),
    Peek     => 1,
    Uid      => 1,
) or die "Cannot connect: $@";

#$imap->State( Mail::IMAPClient::Connected() );
#$imap->login() or die 'login(): ' . $imap->LastError();

my $count = 0;

for $mailbox (@mailboxes) {
	print "Cleaning mailbox $mailbox\n";
	
	# Load list of read messages from last run
	# ----------------------------------------
	open( READLISTFILE, $config->READLISTDIR() . ".imapclean.read.$mailbox" );
	my @readlist = <READLISTFILE>;
	close READLISTFILE;
	foreach (@readlist) { chomp; }
	my %read_old;
	for (@readlist) { $read_old{$_} = 1; }
	
    $imap->select($mailbox);

    # For _zDone, mark all as read
    if ( $mailbox eq "INBOX._zDone" ) {
        my @done_messages = $imap->search('UNDELETED');
        $imap->set_flag( "Seen", @done_messages );
    }

    # Get list of currently read messages
    # ----------------------------------------
    my @read_messages      = $imap->search('UNDELETED SEEN');
    foreach my $message (@read_messages) {
		next unless($message);
        $count++;
        my $data = $imap->parse_headers( $message, "Subject", "From" );

		if(!$data) {
			print "Error parsing message $message headers:\n\n" . $imap->message_string($message);
			die;
		}

        my $address = $data->{From}->[0];

		if(!$address) {
			print "Error getting From address from $message:\n\n" . $imap->message_string($message);
			die;
		}

        $address = $1
          if ( $address =~ m/[<"]?([^\s@]+@[^\s@>"]+)"?>?/ );

        printf "%5d (%s) %-35.35s %s\n", $count, $message,
          $address,
          ( ( defined $data->{Subject}->[0] ) ? $data->{Subject}->[0] : '' );
        $imap->see($message) || die "Can't see $message";
    }

    # Move union of read messages
    # ----------------------------------------
    for my $message (@read_messages) {
        # my $data = $imap->parse_headers( $message, "Subject", "From" );
        # my $address = $data->{From}->[0];
		next unless($message);
        next unless ( $read_old{"$message"} );

        die "Could not move message $message: $!"
          unless $imap->move( $config->TO, $message );
        print "Moved message $message to " . $config->TO, "\n";
    }

	$imap->expunge($mailbox);

	# Save list of new, unmoved read message
	# ----------------------------------------
	open( READLISTFILE, ">", $config->READLISTDIR() . ".imapclean.read.$mailbox" ) || die "can't open read list for writing";
	for my $message (@read_messages) {
		next unless($message);
	    next if ( $read_old{$message} );
	    print READLISTFILE "$message\n";
	    print "Saving $message for next time...\n";
	}
	close READLISTFILE;
}
