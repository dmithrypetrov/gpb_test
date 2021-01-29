#!/usr/bin/perl

use strict;
use warnings;

use v5.24; # postfix deref

use DBI;
use CGI;
use JSON;
use Date;

my $query = new CGI;
my $address = $query->param('address');
my $json = new JSON;

my $dbh = DBI->connect(
    "dbi:Pg:dbname=test;host=localhost;port=5432",
    'postgres',
    '',
    {AutoCommit => 0, RaiseError => 1, PrintError => 0}
);

my $sql = qq[
    with t as (
        SELECT ? as "address"
    )
    (SELECT created, str
    FROM
        message m
        JOIN t ON m.str LIKE '%'||t.address||'%'
    ORDER BY
        int_id, created
    )
    UNION ALL
    (SELECT created, str
    FROM
        log l
        JOIN t ON l.address = t.address
    ORDER BY
        int_id, created
    )
];

my $response = {data => []};

if ($address) {
    my $sth = $dbh->prepare($sql);
    $sth->execute($address =~ s/_/\\_/r =~ s/%/\\%/r) or die $dbh->errstr;
    my $rownum = 1;
    while ($rownum++ < 100 && (my $ref = $sth->fetchrow_hashref)) {
        $ref->{created} = new Date($ref->{created})->strftime('%F %f');
        push $response->{data}->@*, $ref;
    }
    eval {
        $sth->fetchrow_array;
    };
    unless ($@) {
        $response->{error} = 1;
        $sth->finish;
    }
}

$dbh->disconnect;
print "Content-type: application/json\n\n";
print $json->encode($response);
