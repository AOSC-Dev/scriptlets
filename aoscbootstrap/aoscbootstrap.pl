#!/bin/perl
package aoscbootstrap;
use v5.19;
use strict;
use File::Fetch;
use File::Basename;
use File::Path qw(make_path);
use File::Copy;
use File::Temp qw(tempfile);
use Digest::file qw(digest_file_hex);
use LWP::Simple;
use version;
use feature qw(switch);
use Data::Dumper;
use Getopt::Long;

sub version_compare_mini($$) {
    my ( $a, $b ) = @_;
    my $pattern =
      qr/(?:(?<epoch>\d+):)?(?<version>[^-\n]+)(?:-(?<rel>\d+))?/msp;
    my %a_version = %+ if ( $a =~ /$pattern/ );
    my %b_version = %+ if ( $b =~ /$pattern/ );
    return unless ( %a_version and %b_version );
    my $epoch_result =
      int( $a_version{'epoch'} ) <=> int( $b_version{'epoch'} );
    return $epoch_result unless $epoch_result == 0;
    my $version_result = 0;

    if (   $a_version{'version'} =~ /[^0-9\.]+/
        or $b_version{'version'} =~ /[^0-9\.]+/ )
    {
        $version_result = $a_version{'version'} cmp $b_version{'version'};
    }
    else {
        $version_result =
          version->parse( sprintf( "v%s", $a_version{'version'} ) )
          <=> version->parse( sprintf( "v%s", $b_version{'version'} ) );
    }
    return $version_result unless $version_result == 0;
    my $rel_result = int( $a_version{'rel'} ) <=> int( $b_version{'rel'} );
    return $rel_result;
}

sub download_file(%) {
    my (%args) = @_;
    my $ff     = File::Fetch->new( uri => $args{'url'} );
    my $file   = $ff->fetch( to => $args{'to'} ) or die $ff->error;
    return $ff->output_file;
}

sub download_file_named(%) {
    my (%args) = @_;
    my $directory = dirname( $args{'to'} );
    make_path($directory) unless -d $directory;
    my $resp = getstore( $args{'url'}, $args{'to'} );
    is_success($resp) or die sprintf( "Fetch error: %s", $resp );
}

sub find_package($$) {
    my $str     = shift;
    my $name    = shift;
    my $package = $name =~ s/\+/\\\+/gr;
    my $regex =
qr/Package:\h+$package\nVersion:\s+(?<version>.*?)\n.*?Filename:\h+(?<filename>.*?)\n.*?SHA256:\h+(?<sha>.*?)\n((?:(?!\n\n).)*Depends:\h*(?<deps>.*?)\n)?/msp;
    my %candidate = undef;
    while ( $str =~ /$regex/g ) {
        my $result = version_compare_mini( $+{version}, $candidate{version} );
        %candidate = %+ unless ( %candidate and $result and $result <= 0 );
    }
    return undef unless %candidate{filename};
    $candidate{name} = $name;
    return %candidate;
}

sub find_package_depends(%) {
    my (%package) = @_;
    return if !$package{'deps'};
    my @deps = split( /, /, $package{'deps'} );
    foreach my $d (@deps) {
        my @name = split( /\s+/, $d );
        $d = @name[0];
    }
    return @deps;
}

sub find_package_complete($@) {
    my $name = shift;
    my (@manifests) = @_;
    foreach my $m (@manifests) {

# http://blogs.perl.org/users/leon_timmermans/2013/05/why-you-dont-need-fileslurp.html
        my $manifest = do { local ( @ARGV, $/ ) = $m; <> };
        my %package  = find_package( $manifest, $name );

    # if the hash contains "name" field we will assume the package data is valid
        return %package if $package{name};
    }
    return undef;
}

sub resolve_packages($) {
    my $args_ref  = shift;
    my %args      = %$args_ref;
    my @manifests = @{ $args{'manifests'} };
    my @packages  = @{ $args{'packages'} };
    my @resolve_packages;
    foreach my $p (@packages) {
        my %r = find_package_complete( $p, @manifests );
        push @resolve_packages, \%r if %r;
        my @r_deps = find_package_depends(%r);

        # printf ("$r{name} -> %s", Dumper(\@r_deps));
        foreach my $d (@r_deps) {
            push @packages, $d unless ( $d ~~ @packages );
        }
    }
    return @resolve_packages;
}

sub fetch_manifests($) {
    my $args_ref  = shift;
    my %args      = %$args_ref;
    my $mirror    = $args{'mirror'};
    my $branch    = $args{'branch'};
    my $target    = $args{'target'};
    my @manifests = @{ $args{'arch'} };
    my @manifests_location;
    foreach my $arch (@manifests) {
        my $manifest      = "$mirror/dists/$branch/main/binary-$arch/Packages";
        my $manifest_name = $manifest =~ s/^[^:]+:\/\///r =~ s/\//_/gr;
        my $manifest_location = "$target/var/lib/apt/lists/$manifest_name";
        download_file_named( 'url' => $manifest, 'to' => $manifest_location );
        push @manifests_location, $manifest_location;
    }
    return @manifests_location;
}

sub fetch_packages($$@) {
    my $mirror     = shift;
    my $target     = shift;
    my (@packages) = @_;
    my $count      = 0;
    my $length     = scalar @packages;
    my $cache_dir  = "$target/var/cache/apt/archives/partial/";
    for my $dep (@packages) {
        $count++;
        my %pkg = %$dep;
        print "[$count/$length] Downloading $pkg{'name'}...\n";
        my $filename =
          download_file( url => "$mirror/$pkg{'filename'}", to => $cache_dir );
        print "[$count/$length] Verifying $pkg{'name'}...\n";
        digest_file_hex( "$cache_dir/$filename", "SHA-256" ) == $pkg{'sha'}
          or die "Failed to verify $pkg{'name'}";
        move( "$cache_dir/$filename", "$cache_dir/../$filename" );
    }
}

sub extract_deb_dpkg($$) {
    my $from = shift;
    my $to   = shift;
    `dpkg-deb -x '$from' '$to'`;
    $? == 0 or die "Failed to extract files";
}

sub extract_deb_ar($$) {
    my $from      = shift;
    my $to        = shift;
    my $data_file = `ar -t '$from' | grep "^data.tar"`;
    $data_file =~ s/\s+//g;
    my $tar_filter = '';
    for ($data_file) {
        $tar_filter = 'z' when /^data\.tar\.gz/;
        $tar_filter = 'J' when /^data\.tar\.xz/;
        $tar_filter = '' when /^data\.tar/;
        default { die "Unsupported data file: $data_file" }
    }
    `ar -p '$from' '$data_file' | tar x${tar_filter}f - -C '$to'`;
    $? == 0 or die "Failed to extract files";
}

sub detect_extractor() {
    return "dpkg-deb" if system( ( "which", "dpkg-deb" ) ) == 0;
    return "ar"       if system( ( "which", "ar" ) ) == 0;
    return undef;
}

sub extract_deb($$) {
    my $from      = shift;
    my $to        = shift;
    my $extractor = $aoscbootstrap::extractor;
    return extract_deb_ar( $from, $to )   if $extractor eq 'ar';
    return extract_deb_dpkg( $from, $to ) if $extractor eq 'dpkg-deb';
}

sub extract_packages($) {
    my $args_ref         = shift;
    my %args             = %$args_ref;
    my @manifests        = @{ $args{'manifests'} };
    my @packages         = @{ $args{'packages'} };
    my $target           = $args{'target'};
    my @extract_packages = resolve_packages( \%args );
    my $length           = scalar @extract_packages;
    my $count            = 0;

    foreach my $p ( reverse @extract_packages ) {
        $count++;
        my %pkg = %$p;
        print "[$count/$length] Extracting $pkg{'name'}...\n";
        my $pkg_filename = basename( $pkg{'filename'} );
        extract_deb( "$target/var/cache/apt/archives/$pkg_filename", $target );
    }
}

sub chroot_do($@) {
    my $target = shift;
    my @cmd    = @_;
    system( 'chroot', "$target", @cmd ) == 0
      or die("Command failed when executing in chroot: $cmd[0]\n");
}

sub chroot_script_do($$) {
    my $target = shift;
    my $script = shift;
    my ( $fh, $filename ) =
      tempfile( "ab-XXXXXX", SUFFIX => '.sh', DIR => "$target/aoscbootstrap" )
      or die("Cannot create temporary file");
    print $fh "$script\n";
    close($fh);
    $filename = basename($filename);
    chroot_do( $target, "/bin/bash", "-e", "/aoscbootstrap/$filename" );
    unlink("$target/aoscbootstrap/$filename");
}

sub bootstrap_apt(%) {
    my $args_ref = shift;
    my %args     = %$args_ref;
    my $mirror   = $args{'mirror'};
    my $branch   = $args{'branch'};
    my $target   = $args{'target'};
    make_path("$target/var/lib/dpkg")
      or die "Could not create directory"
      unless -d "$target/var/lib/dpkg";
    make_path("$target/etc/apt")
      or die "Could not create directory"
      unless -d "$target/etc/apt";
    die "Unable to bootstrap Dpkg available file."
      unless open( FH, ">$target/var/lib/dpkg/available" );
    close(FH);
    die "Unable to bootstrap Dpkg state file."
      unless open( FH, ">$target/var/lib/dpkg/status" );
    close(FH);
    die "Unable to bootstrap APT sources file."
      unless open( FH, ">$target/etc/apt/sources.list" );
    print FH "deb $mirror $branch main\n";
    close(FH);
    die "Unable to bootstrap locale file."
      unless open( FH, ">$target/etc/locale.conf" );
    print FH "LANG=C.UTF-8\n";
    close(FH);
    die "Unable to bootstrap shadow file."
      unless open( FH, ">$target/etc/shadow" );
    print FH "root:x:1:0:99999:7:::\n";
    close(FH);
}

sub mknod(@) {
    my $device = shift;
    my $type   = shift;
    my $major  = shift;
    my $minor  = shift;
    return if -e "$device";
    system( ( "mknod", "-m", "666", $device, $type, $major, $minor ) ) == 0
      or die "Could not create device $device";
}

sub bootstrap_dev_nodes($) {
    my $target = shift;
    mknod( "$target/dev/null",    'c', 1, 3 );
    mknod( "$target/dev/console", 'c', 5, 1 );
    make_path("$target/dev/shm")
      or die "Failed to mkdir $target/dev/shm"
      unless -d "$target/dev/shm";
    chmod 1777, "$target/dev/shm" or die "Failed to chmod $target/dev/shm";
}

sub generate_dpkg_install_script(@) {
    my (@packages) = @_;
    my $script = '';
    open( my $fh, '>', \$script )
      or die "Could not open an in-memory file descriptor...\n";
    print $fh "#!/bin/bash\ncount=0\nPACKAGES=(\n";
    foreach my $p ( reverse @packages ) {
        my %pkg          = %$p;
        my $pkg_filename = basename( $pkg{'filename'} );
        print $fh "  '$pkg_filename'\n";
    }
    print $fh ")\nlength=\${#PACKAGES[@]}\nfor p in \${PACKAGES[@]}; do\n";
    print $fh "  count=\$((count+1))\n";
    print $fh "  echo \"[\$count/\$length] Installing \${p}...\"\n";
    print $fh
"  dpkg --force-depends --unpack \"/var/cache/apt/archives/\${p}\"\ndone\n";
    print $fh
      "dpkg --configure --pending --force-configure-any --force-depends\n";
    close($fh);
    return $script;
}

sub add_packages_from_file($$) {
    my $filename = shift;
    my $packages_ref = shift;
    open(my $fh, '<', $filename) or die "Could not open $filename";
    while (<$fh>) {
        my $name = $_ =~ s/^\s+|\s+$//gr;
        push @{$packages_ref}, $name;
    }
    close($fh);
    print STDERR "Added additional packages from $filename\n";
}

# configurations
my $default_mirror = 'https://repo.aosc.io/debs';
my $default_branch = 'stable';
my @arch           = ('all');
my @recipe_files   = ();
my @stub_packages  = (
    'apt',    'gcc-runtime', 'tar',      'xz',
    'gnupg',  'grep',        'ca-certs', 'iptables',
    'shadow', 'keyutils'
);
my @base_packages = (
    @stub_packages, 'bash-completion', 'bash-startup', 'iana-etc', 'libidn',
    'tzdata'
);

GetOptions( "arch=s" => \@arch, "include=s" => \@base_packages, "include-file=s" => \@recipe_files );
my $arch_length = scalar @arch;
die "ERROR: You must specify an architecture using --arch" if $arch_length < 2;
my $branch = shift @ARGV || $default_branch;
my $target = shift @ARGV || die "ERROR: No target specified!\n";
my $mirror = shift @ARGV || $default_mirror;
print STDERR
  "Bootstrapping using mirror: $mirror with branch: $branch on $target\n";
my %args = (
    'target' => $target,
    'mirror' => $mirror,
    'branch' => $branch,
    'arch'   => \@arch
);

if (@recipe_files) {
    foreach my $recipe (@recipe_files) {
        add_packages_from_file($recipe, \@base_packages);
    }
}

make_path("$target/aoscbootstrap")
  or die "Failed to mkdir $target/aoscbootstrap";
print STDERR "Downloading manifests...\n";
my @manifests = fetch_manifests( \%args );

print STDERR "Determining what packages to download...\n";
push( @base_packages, @stub_packages );
my %args_2   = ( packages => \@base_packages, manifests => \@manifests );
my @all_deps = resolve_packages( \%args_2 );
print STDERR "Downloading packages...\n";
fetch_packages( $mirror, $target, @all_deps );
print STDERR "Dowloading extra files...\n";
`curl -q 'https://repo.aosc.io/aosc-repacks/etc-bootstrap.tar.xz' | tar xJf - -C "$target"`;
$? == 0 or die "Failed to download extra files\n";

our $extractor = detect_extractor();
make_path($target) unless -d $target;
my %args_3 = (
    'manifests' => \@manifests,
    'packages'  => \@stub_packages,
    'target'    => $target
);
extract_packages( \%args_3 );
bootstrap_apt( \%args );
bootstrap_dev_nodes($target);
print STDERR "Stage 1 finished.\n";

# HACK: correct path problems
# `cp -ar "$target/bin/"* "$target/usr/bin/" && rm -rf "$target/bin/" && ln -s usr/bin "$target/bin"`;
# `cp -ar "$target/usr/lib64/"* "$target/usr/lib/" && rm -rf "$target/usr/lib64/" && ln -s lib "$target/usr/lib64"`;
# stage 2
print STDERR "================================\n";
print STDERR "Setting default passwords...\n";
chroot_do( "$target", "/bin/true" );
`echo 'root:anthon' | chpasswd -R '$target'`;
print STDERR "Installing packages for stage 2...\n";
my $script = generate_dpkg_install_script(@all_deps);
chroot_script_do( $target, $script );
print STDERR "Installing skeleton scripts for root user...\n";
chroot_do( "$target", '/bin/cp', '-rT', '/etc/skel', '/root' );
print STDERR "================================\n";
print STDERR "Base system setup complete.\n";
