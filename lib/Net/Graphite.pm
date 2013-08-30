package Net::Graphite;
use strict;
use warnings;
use Carp qw/confess/;
use IO::Socket::INET;

$Net::Graphite::VERSION = '0.12';

our $TEST = 0;   # if true, don't send anything to graphite

sub new {
    my $class = shift;
    return bless {
        host            => '127.0.0.1',
        port            => 2003,
        fire_and_forget => 0,
        proto           => 'tcp',
        timeout         => 1,
        # path
        @_,
        # _socket
    }, $class;
}

sub trace {
    my (undef, $val_line) = @_;
    print STDERR $val_line;
}

sub send {
    my $self = shift;
    my $value;
    $value = shift if @_ % 2;

    my %args = @_;
    $value = $args{value} unless defined $value;
    my $path = $args{path} || $self->{path};
    my $time = $args{time} || time;

    my $plaintext = "$path $value $time\n";

    $self->trace($plaintext) if $self->{trace};

    unless ($Net::Graphite::TEST) {
        if ($self->connect()) {
            # for now, I'll assume these don't fail...
            $self->{_socket}->send($plaintext);
        }
        # I didn't close the socket!
    }

    return $plaintext;
}

sub path {
    my ($self, $path) = @_;
    $self->{path} = $path if defined $path;
    return $self->{path};
}

sub connect {
    my $self = shift;
    return $self->{_socket}
      if $self->{_socket} && $self->{_socket}->connected;

    $self->{_socket} = IO::Socket::INET->new(
        PeerHost => $self->{host},
        PeerPort => $self->{port},
        Proto    => $self->{proto},
        Timeout  => $self->{timeout},
    );
    confess "Error creating socket: $!"
      if not $self->{_socket} and not $self->{fire_and_forget};

    return $self->{_socket};
}

# if you need to close/flush for some reason
sub close {
    my $self = shift;
    $self->{_socket}->close();
    $self->{_socket} = undef;
}

1;
__END__

=pod

=head1 NAME

Net::Graphite - Interface to Graphite

=head1 SYNOPSIS

  use Net::Graphite;
  my $graphite = Net::Graphite->new(
      # except for host, these hopefully have reasonable defaults, so are optional
      host => '127.0.0.1',
      port => 2003,
      trace => 0,            # if true, copy what's sent to STDERR
      proto => 'tcp',        # can be 'udp'
      timeout => 1,          # timeout of socket connect in seconds
      fire_and_forget => 0,  # if true, ignore sending errors

      path => 'foo.bar.baz', # optional, use when sending single values
  );

  # send a single value,
  # need to set path in the call to new
  # or call $graphite->path('some.path') beforehand
  $graphite->send(6);        # default time is "now"

 -OR-

  # send a metric with named parameters
  $graphite->send(
      path => 'foo.bar.baz',
      value => 6,
      time => time(),        # time defaults to "now"
  );

 -OR-

  # send text with one line per metric, following the plaintext protocol
  $graphite->send(plaintext => $string_with_one_line_per_metric);

=head1 DESCRIPTION

Interface to Graphite which doesn't depend on AnyEvent.

=head1 INSTANCE METHODS

=head2 close

Explicitly close the socket to the graphite server.
Not normally needed,
because the socket will close when the $graphite object goes out of scope.

=head2 connect

Get an open a socket to the graphite server, either the currently connected one
or, if not already connected, a new one.
Not normally needed.

=head2 path

Set the default path (corresponds to 'path' argument to new),
for use when sending single values.

=head2 send

Normally all you need to use. See the SYNOPSIS.

=head1 SEE ALSO

AnyEvent::Graphite

L<http://graphite.readthedocs.org/>

=head1 AUTHOR

Scott Lanning E<lt>slanning@cpan.orgE<gt>

=cut
