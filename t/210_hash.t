use strict;
use warnings;

use Test::More tests => 4;

use Net::Graphite;
$Net::Graphite::TEST = 1;

{
    my $graphite = Net::Graphite->new(path => 'who.what');

    my $hash = {
        1377872333 => {
            a => { one   => 1, two  => 2 },
            b => { three => 3, four => 4 },
        },
        1377872334 => {
            a => { one   => 1, two  => 2 },
            c => { five  => 5, six  => 6 },
        },
    };

    my $sent = $graphite->send(data => $hash);    # default hash transformer

    my $expected = <<'TXT';
who.what.a.one 1 1377872333
who.what.a.two 2 1377872333
who.what.b.four 4 1377872333
who.what.b.three 3 1377872333
who.what.a.one 1 1377872334
who.what.a.two 2 1377872334
who.what.c.five 5 1377872334
who.what.c.six 6 1377872334
TXT

    is($sent, $expected, 'sent hash');

    my $graphite_no_path = Net::Graphite->new();
    my $sent_with_path = $graphite_no_path->send( path => 'who.what', data => $hash );

    is($sent_with_path, $expected, 'sent hash without hardcoded root path');
}

{
    use utf8;

    my $graphite = Net::Graphite->new(path => '谁.什么');

    my $hash = {
        1377872333 => {
            a => { one   => 1, two  => 2 },
            b => { three => 3, four => 4 },
        },
        1377872334 => {
            a => { one   => 1, two  => 2 },
            c => { five  => 5, six  => 6 },
        },
    };

    my $sent = $graphite->send(data => $hash);    # default hash transformer

    my $expected = <<'TXT';
谁.什么.a.one 1 1377872333
谁.什么.a.two 2 1377872333
谁.什么.b.four 4 1377872333
谁.什么.b.three 3 1377872333
谁.什么.a.one 1 1377872334
谁.什么.a.two 2 1377872334
谁.什么.c.five 5 1377872334
谁.什么.c.six 6 1377872334
TXT

    # unexpectedly it matches!?! I think I'm testing it wrong
    # or otherwise don't understand..
    #is($sent, $expected, 'sent utf8-keyed hash');

    isnt($sent, $expected, "UTF-8 paths shouldn't contain UTF-8");
    is($sent, '', "UTF-8 paths should be skipped");
}
