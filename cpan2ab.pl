#!/bin/perl
use v5.19;
use strict;
use LWP::UserAgent ();
use Data::Dumper;
use Getopt::Long;
use JSON;
use File::Path qw(make_path);

sub query_on_cpan($$) {
    my $name           = shift;
    my $dist_name_only = shift;
    my $ua             = LWP::UserAgent->new( timeout => 10 );
    $ua->env_proxy;
    print STDERR "-- Querying module $name on CPAN...\n";
    my $response = $ua->get("https://fastapi.metacpan.org/v1/module/$name");
    if ( !$response->is_success ) {
        die $response->status_line;
    }
    my $metadata  = decode_json( $response->decoded_content );
    my %metadata  = %$metadata;
    my $dist_name = %metadata{'distribution'};
    die "Cannot find distribution name for module $name" unless $dist_name;
    return $dist_name if $dist_name_only;
    print STDERR "-- Found $name in package distribution $dist_name\n";
    my $response =
      $ua->get("https://fastapi.metacpan.org/v1/release/$dist_name");

    if ( !$response->is_success ) {
        die $response->status_line;
    }
    my $release_data = decode_json( $response->decoded_content );
    my %release      = %$release_data;
    print STDERR "-- Found release information for distribution $dist_name\n";
    my %package = (
        'version'     => $release{'version_numified'},
        'name'        => $dist_name,
        'description' => $metadata{'abstract'},
        'sha256sum'   => $release{'checksum_sha256'},
        'tarball'     => $release{'download_url'},
        'depends'     => $release{'dependency'}
    );

    return \%package;
}

sub normalize_name($) {
    my $name            = shift;
    my $normalized_name = lc($name);
    $normalized_name =~ s/::/-/g;
    return $normalized_name;
}

sub infer_deps($) {
    my $deps         = shift;
    my @deps         = @$deps;
    my @rt_deps      = ();
    my @build_deps   = ();
    my @core_imports = ();
    foreach my $inc(@INC) {
        push @core_imports, "\'$inc\'" if $inc =~ m/core_perl$/;
    }
    my $imports = join(", ", @core_imports);

    foreach my $dep (@deps) {
        my %d = %$dep;
        next if $d{'relationship'} ne 'requires';
        next if system('perl', '-e', "\@INC=($imports);require $d{'module'};") == 0;
        my $dist_name = query_on_cpan( $d{'module'}, 1 );
        next if $dist_name eq 'perl';
        my $name      = normalize_name($dist_name);
        if ( $d{'phase'} eq 'runtime' ) {
            push @rt_deps, "perl-$name" unless ( "perl-$name" ~~ @rt_deps );
        }
        else {
            push @build_deps, "perl-$name"
              unless ( "perl-$name" ~~ @build_deps );
        }
    }

    my %args = ( 'deps' => \@rt_deps, 'build_deps' => \@build_deps );
    return \%args;
}

sub ab3_writer($) {
    my $data            = shift;
    my %data            = %$data;
    my $normalized_name = normalize_name( $data{'name'} );
    my $ab_name         = "perl-$normalized_name";
    my $ab_srcurl       = $data{'tarball'} =~ s/$data{'version'}/\$VER/gr;
    my $deps            = infer_deps( $data{'depends'} );
    my %deps            = %$deps;
    my $rt_deps         = join( ' ', @{ $deps{'deps'} } );
    my $build_deps      = join( ' ', @{ $deps{'build_deps'} } );
    print STDERR "-- Writing abbs build files: $ab_name\n";
    make_path($ab_name) or die "Could not create directory $ab_name";
    die "Could not write to $ab_name/spec" unless open( FH, ">$ab_name/spec" );
    print FH
"VER=$data{'version'}\nSRCTBL=\"$ab_srcurl\"\nCHKSUM='sha256::$data{'sha256sum'}'\n";
    close(FH);
    make_path("$ab_name/autobuild")
      or die "Could not create directory $ab_name/autobuild";
    die "Could not write to $ab_name/spec"
      unless open( FH, ">$ab_name/autobuild/defines" );
    print FH
"PKGNAME=$ab_name\nPKGSEC=perl\nPKGDES='$data{'description'}'\nPKGDEP=\"perl $rt_deps\"\nBUILDDEP=\"$build_deps\"\n";
    close(FH);
    print STDERR "-- Writing abbs build files: $ab_name - OK\n";
    return \%deps;
}

foreach my $module (@ARGV) {
    my $data = query_on_cpan( $module, 0 );
    ab3_writer($data);
}
