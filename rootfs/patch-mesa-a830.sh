#!/bin/sh
# Backport Mesa commit 2061a5ee (A830v1 mainline DRM chip-id support) to
# Alpine's Mesa 26.1.6 libgallium without rebuilding the full Mesa package.
set -eu

src=${1:?usage: patch-mesa-a830.sh SOURCE DESTINATION}
dst=${2:?usage: patch-mesa-a830.sh SOURCE DESTINATION}
tmp="${dst}.tmp.$$"

trap 'rm -f "$tmp"' EXIT HUP INT TERM

perl - "$src" "$tmp" <<'PERL'
use strict;
use warnings;

my ($src, $dst) = @ARGV;
my @old = (
    pack('H*', '00000544ffff0000'), # 0x0000ffff44050000 (Mesa 26.1)
    pack('H*', '0000054400000000'), # 0x0000000044050000 (Mesa 26.0)
);
my $new = pack('H*', '01000544ffff0000'); # 0x0000ffff44050001

open my $in, '<:raw', $src or die "open $src: $!\n";
local $/;
my $data = <$in>;
close $in;

my @old_count = map { scalar(() = $data =~ /\Q$_\E/g) } @old;
my $old_count = 0;
$old_count += $_ for @old_count;
my $new_count = () = $data =~ /\Q$new\E/g;

if ($old_count == 1 && $new_count == 0) {
	for my $i (0 .. $#old) {
		next unless $old_count[$i];
		$data =~ s/\Q$old[$i]\E/$new/;
		last;
	}
} elsif (!($old_count == 0 && $new_count == 1)) {
	die "unexpected A830 device-table patterns: old=@old_count new=$new_count\n";
}

open my $out, '>:raw', $dst or die "open $dst: $!\n";
print {$out} $data;
close $out or die "close $dst: $!\n";
PERL

chmod --reference="$src" "$tmp"
mv -f "$tmp" "$dst"
trap - EXIT HUP INT TERM

echo "Mesa A830v1 chip-id entry ready: $dst"
