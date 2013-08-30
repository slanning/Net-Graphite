package Net::Graphite;
use strict;
use warnings;
use Carp qw/confess/;
use IO::Socket::INET;
use Scalar::Util qw/reftype/;

$Net::Graphite::VERSION = '0.13';

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
        # transformer
        @_,
        # _socket
    }, $class;
}

sub send {
    my $self = shift;
    my $value;
    $value = shift if @_ % 2;   # single value passed in
    my %args = @_;

    my $plaintext;
    if ($args{data}) {
        my $xform = $args{transformer} || $self->transformer;
        if ($xform) {
            $plaintext = $xform->($args{data});
        }
        else {
            if (ref $args{data}) {
                my $reftype = reftype $args{data};

                # default transformers
                if ($reftype eq 'HASH') {
                    # hash structure from Yves
                    foreach my $epoch (sort {$a <=> $b} keys %{ $args{data} }) {
                        _fill_lines_for_epoch(\$plaintext, $epoch, $args{data}{$epoch}, $self->path);
                    }
                }
                else {
                    confess "Arg 'data' passed to send method is a ref but has no plaintext transformer";
                }
            }
            else {
                # this obsoletes plaintext; just pass 'data' without a transformer
                $plaintext = $args{data};
            }
        }
    }
    else {
        $value   = $args{value} unless defined $value;
        my $path = $args{path} || $self->path;
        my $time = $args{time} || time;

        $plaintext = "$path $value $time\n";
    }

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

sub _fill_lines_for_epoch {
    # note: $in_out_str_ref is a reference to a string,
    # not so much for performance but as an accumulator in this recursive function
    my ($in_out_str_ref, $epoch, $hash, $path) = @_;

    # still in the "branches"
    if (ref $hash) {
        foreach my $key (sort keys %$hash) {
            my $value = $hash->{$key};
            _fill_lines_for_epoch($in_out_str_ref, $epoch, $value, "$path.$key");
        }
    }
    # reached the "leaf" value
    else {
        $$in_out_str_ref .= "$path $hash $epoch\n";
    }
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

sub trace {
    my (undef, $val_line) = @_;
    print STDERR $val_line;
}

### mutators
sub path {
    my ($self, $path) = @_;
    $self->{path} = $path if defined $path;
    return $self->{path};
}
sub transformer {
    my ($self, $xform) = @_;
    $self->{transformer} = $xform if defined $xform;
    return $self->{transformer};
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
  $graphite->send(data => $string_with_one_line_per_metric);

 -OR-

  # send a data structure with a coderef to transform it to plaintext
  $graphite->send(data => $hash);   # HoH -> epoch => key => key => key .... => value
  $graphite->send(data => $whatever, transformer => \&make_whatever_into_plaintext);

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

Normally all you need to use. See the SYNOPSIS. (FIXME)

=head2 transformer

If you pass a 'data' argument to send,
use this coderef to transform from the data structure to plaintext.
The coderef receives the data structure as its only parameter.
There are default transformers for certain reftypes.

=head1 SEE ALSO

AnyEvent::Graphite

L<http://graphite.readthedocs.org/>

=head1 AUTHOR

Scott Lanning E<lt>slanning@cpan.orgE<gt>

=cut
