use strict;
use warnings;
use File::Path qw(make_path);
use File::Basename;
use File::Copy;

sub read_file_pure {
    my ($file) = @_;
    open my $fh, '<:encoding(UTF-8)', $file or die "Could not open $file: $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    return $content;
}

sub write_file_pure {
    my ($file, $content) = @_;
    open my $fh, '>:encoding(UTF-8)', $file or die "Could not open $file: $!";
    print $fh $content;
    close $fh;
}

sub dircopy {
    my ($src, $dst) = @_;
    return unless -d $src;
    opendir(my $dfh, $src) or return;
    make_path($dst) unless -d $dst;
    while (my $f = readdir($dfh)) {
        next if $f =~ /^[.]/;
        if (-d "$src/$f") { dircopy("$src/$f", "$dst/$f"); }
        else { copy("$src/$f", "$dst/$f"); }
    }
    closedir($dfh);
}

sub get_meta {
    my ($raw) = @_;
    my ($meta_block, $body) = $raw =~ /^---\s*(.*?)\s*---\s*(.*)/s;
    my %meta;
    $meta{content} = $body || $raw;
    if ($meta_block) {
        foreach (split /\n/, $meta_block) {
            my ($k, $v) = split /:\s*/, $_, 2;
            if ($k && $v) {
                $v =~ s/^\s+|\s+$//g;
                $meta{lc($k)} = $v;
            }
        }
    }
    return \%meta;
}

sub slugify {
    my ($text) = @_;
    $text = lc($text // "");
    $text =~ s/[^a-z0-9]+/-/g;
    $text =~ s/^-+|-+$//g;
    return $text;
}

1;