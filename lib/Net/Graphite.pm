package Net::Graphite;
use strict;
use warnings;
use Carp qw/confess/;
use IO::Socket::INET;

$Net::Graphite::VERSION = '0.10';

our $TEST = 0;

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
      host => '127.0.0.1',   # default
      port => 2003,          # default
      path => 'foo.bar.baz', # optional
      trace => 0,            # copy output to STDERR if true
  );
  $graphite->send(6);        # default time is "now"

 OR

  my $graphite = Net::Graphite->new(
      host => '127.0.0.1',   # default
      port => 2003,          # default
      fire_and_forget => 1,  # if I can't send, I don't care!
  );
  $graphite->send(
      path => 'foo.bar.baz',
      value => 6,
      time => time(),
  );

=head1 DESCRIPTION

Interface to Graphite which doesn't depend on AnyEvent.

=head1 SEE ALSO

AnyEvent::Graphite

http://graphite.wikidot.com/

=head1 AUTHOR

Scott Lanning E<lt>slanning@cpan.orgE<gt>

=cut
