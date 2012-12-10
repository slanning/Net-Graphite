use strict;
use warnings;

use Test::More tests => 7;

use Net::Graphite;
$Net::Graphite::TEST = 1;

{
    my $graphite = Net::Graphite->new();
    is($graphite->{host}, '127.0.0.1', 'host default');
    is($graphite->{port}, 2003, 'port default');

    my $sent = $graphite->send(
        path => 'foo.bar',
        value => 23,
        time => 1000000000,
    );
    is($sent, "foo.bar 23 1000000000\n", 'sent args');
}

{
    my $graphite = Net::Graphite->new(
        host => '127.0.0.2',
        port => 2004,
        path => 'foo.bar.baz',
    );

    is($graphite->{host}, '127.0.0.2', 'host set');
    is($graphite->{port}, 2004, 'port set');
    is($graphite->{path}, 'foo.bar.baz', 'path set');

    my $sent = $graphite->send(6);
    like($sent, qr/^foo\.bar\.baz 6 [0-9]{10}$/, 'sent value');
}
