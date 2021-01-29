#!/usr/bin/perl
use strict;
use warnings;
no warnings 'experimental::smartmatch';

use v5.20;

use DBI;
use Date;

my $dbh = DBI->connect(
    "dbi:Pg:dbname=test;host=localhost;port=5432",
    'postgres',
    '',
    {AutoCommit => 0, RaiseError => 1, PrintError => 0}
);

my $sth_message = $dbh->prepare(qq[
    INSERT INTO message (created, int_id, id, str, status) VALUES (?, ?, ?, ?, TRUE)
]);
my $sth_log = $dbh->prepare(qq[
    INSERT INTO log (created, int_id, str, address) VALUES (?, ?, ?, ?)
]);

my $file = $ARGV[0];
open my $h, '<', $file or die $!;

my $lnum = 1;
while (my $line = <$h>) {
    my $saved_line = $line;
    my %content;
    $content{created} = new Date(substr($line, 0, 19, ''))->to_string(Date::FORMAT_ISO);
    substr $line, 0, 1, '';
    $content{str} = $line;
    $content{int_id} = substr($line, 0, 16, '');
    substr $line, 0, 1, '';
    
    $line =~ /(?<timestamp>\S+ \S+) (?<int_id>) /;
    my $flag = substr($line, 0, 2);
    if ('<=' eq $flag) {
        next if '<>' eq substr($line, 3, 2);
        $line =~ /<= (?<address>\S+).+?(?<id>id=\S+)/;
        next unless $+{id};
        @content{qw/address id/} = @+{qw/address id/};
        $sth_message->execute(@content{qw/created int_id id str/});
    } else {
        $content{log_type} = 'log';
        if ($flag ~~ [qw/== ** => ->/]) {
            $line =~ /\S\S (\S+)/;
            $content{address} = $1;
        }
        $sth_log->execute(@content{qw/created int_id str address/});
    }
}

close $h;
$dbh->commit;


