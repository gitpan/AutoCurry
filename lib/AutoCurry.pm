package AutoCurry;

# Tom Moertel <tom@moertel.com>
# 2004-11-16

=head1 NAME

AutoCurry - automatically create currying variants of functions

=head1 SYNOPSIS

    use AutoCurry qw( foo );  # pass :all to curry all functions

    sub foo { print "@_\n"; }
    # currying variant, foo_c, is created automatically

    my $hello = foo_c("Hello,");
    $hello->("world!");       # Hello, world!
    $hello->("Pittsburgh!");  # Hello, Pittsburgh!

=cut

use Carp;

use warnings;
use strict;

our $VERSION = 0.10_01;

my $PKG = __PACKAGE__;

sub _debug { print STDERR "AutoCurry: @_\n" if $ENV{AUTOCURRY_DEBUG} }

sub curry {
    my $f = shift;
    my $args = \@_;
    sub { $f->(@$args, @_) };
}

sub curry_package {
    my $pkg = shift || caller;
    curry_named_functions_from_package( $pkg,
        get_function_names_from_package( $pkg )
    );
}

sub curry_named_functions {
    return curry_named_functions_from_package( scalar caller(), @_ );
}

sub curry_named_functions_from_package {
    no strict 'refs';
    my $pkg = shift() . "::";
    map {
        my $curried_name = $_ . "_c";
        carp "$PKG: currying $_ over existing $curried_name"
            if *$curried_name{CODE};
        _debug("making $curried_name");
        *$curried_name = curry( \&curry, \&$_ );
        $curried_name;
    } map { /::/ ? $_ : "$pkg$_" } @_;
}

sub get_function_names_from_package {
    no strict 'refs';
    my $pkg = shift || caller;
    my $symtab = *{ $pkg . "::" }{HASH};
    sort grep *$_{CODE},      # drop symbols w/o code
        map  $pkg."::$_",     # fully qualify
        grep !/^_|^[_A-Z]+$/, # drop _underscored & ALL_CAPS
        keys %$symtab;        # get all symbols for package
}

my @init;

sub import {
    shift;  # don't need self
    my $caller = caller;
    push @init, curry_package_c($caller) if grep /^:all$/, @_;
    curry_named_functions_from_package($caller, grep !/^:/, @_);
}

INIT { finish_initialization() }

sub finish_initialization {
    $_->() for @init; @init = ();
}

# physician, curry thyself!

curry_named_functions(qw(
    curry_package
));


1;

__END__

=head1 DESCRIPTION

This module automatically creates currying variants of functions.  For
each function C<foo>, a currying variant C<foo_c> will be created that
(1) captures whatever arguments are passed to it and (2) returns a new
function.  The new function awaits any new arguments that are passed
to I<it>, and then calls the original C<foo>, giving it both the
captured and new arguments.

If C<foo> is a function and C<foo_c> is its currying variant, then the
following are equivalent for all argument lists C<@a> and C<@b>:

    foo(@a, @b);
    foo_c(@a, @b)->();
    foo_c()->(@a, @b);
    foo_c(@a)->(@b);
    do { my $foo1 = foo_c(@a); $foo1->(@b) };

=head2 use AutoCurry I<names>

You can create currying variants at C<use> time by listing the
functions to be curried:

    use AutoCurry qw( foo bar );

Or, if you want to curry everything:

    use AutoCurry ':all';

=head2 curry_named_functions(I<names>) 

You can also create variants at run time:

    my @created_variants =
    AutoCurry::curry_named_functions(qw( foo bar ));

The fully-qualified names of the created functions are returned:

    print "@created_variants";
    # main::foo_c main::bar_c

If you are writing a module, this list of names is handy for
augmenting your export lists.


=head2 curry_package(I<package>)

    AutoCurry::curry_package("My::Package"); # autocurries My::Package
    AutoCurry::curry_package();              # autocurries calling pkg

Creates currying variants for all of the subroutines within the given
package or, if no pacakge is given, the current package from which
C<curry_package> was called.

Returns a list of the functions created.


=head1 MOTIVATION

Currying reduces the cost of reusing functions by allowing you to
"specialize" them by pre-binding values to a subset of their
arguments.  Using it, you can convert any function of I<N> arguments
into a family of I<N> related, specialized functions.

Currying in Perl is somewhat awkward.  My motivation for
writing this module was to minimize that awkwardness and
approximate the "free" currying that modern functional
programming languages such as Haskell offer.

As an example, let's say we have a general-purpose logging function:

    sub log_to_file {
        my ($fh, $heading, $message) = @_;
        print $fh "$heading: $message\n";
    }

    log_to_file( *STDERR, "warning", "hull breach imminent!" );

If we are logging a bunch of warnings to STDERR, we can save some work
by specializing the function for that purpose:

    my $log_warning = sub {
        log_to_file( *STDERR, "warning", @_ );
    };

    $log_warning->("cap'n, she's breakin' up!");

The C<log_warning> function, being tailored for the purpose, is easier
to use.  However, having to create the function is a pain.  We are
effectively currying by hand.  For this reason, many people use a
helper function to curry for them:

    $log_warning = curry( \&log_to_file, *STDERR, "warning" );

An improvement, but still far from free.

This module does away with the manual labor altogether by creating
currying variants of your functions automatically.  These variants
have names ending in a C<_c> suffix and I<automatically curry> the
original functions for the arguments you give them:

    use AutoCurry ':all';
    $log_warning = log_to_file_c( *STDERR, "warning" );

    $log_warning->("she's gonna blow!");

The total cost of currying is reduced to appending a C<_c> suffix,
which is probably as low as it's going to get on this side of Perl 6.

=head1 AUTHOR

    Tom Moertel <tom@moertel.com>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2004-05 by Thomas G Moertel.  All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
