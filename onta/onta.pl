use strict;
use warnings;
use JSON::PP;
use File::Basename;
use Time::HiRes qw(gettimeofday tv_interval);
use File::Path qw(make_path remove_tree);

require './core/Core.pm';
require './core/Engine.pm';

my ($cyan, $green, $blue, $bold, $white, $reset) = ("\e[36m", "\e[32m", "\e[34m", "\e[1m", "\e[37m", "\e[0m");
my $start_time = [gettimeofday];

my $config = JSON::PP->new->utf8->decode(read_file_pure('config.json'));
my ($pub, $layout_dir, $content_dir) = ('../', 'layout', 'content');

my (@all_posts, %colls, %tax, @sitemap_urls);

sub generate_sitemap {
    my ($urls_ref, $site_url) = @_;
    $site_url //= "http://localhost:8000"; 
    my $xml = qq|<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n|;
    foreach my $url (@$urls_ref) {
        my $full_url = $site_url . '/' . $url;
        $full_url =~ s/\/index\.html$/\//;
        $xml .= qq|  <url>\n    <loc>$full_url</loc>\n  </url>\n|;
    }
    $xml .= qq|</urlset>|;
    write_file_pure("$pub/sitemap.xml", $xml);
    print "  ${green}✔${reset} ${white}sitemap.xml${reset}\n";
}

sub generate_robots {
    my ($site_url) = @_;
    $site_url //= "http://localhost:8000";
    
    my $txt = "User-agent: *\n";
    $txt .= "Allow: /\n\n";
    $txt .= "Sitemap: $site_url/sitemap.xml\n";
    
    write_file_pure("$pub/robots.txt", $txt);
    print "  ${green}✔${reset} ${white}robots.txt${reset}\n";
}

sub get_meta {
    my ($raw_content) = @_;
    
    $raw_content =~ s/^\x{EF}\x{BB}\x{BF}//;
    $raw_content =~ s/^\x{FE}\xFF//;
    $raw_content =~ s/^\xFF\xFE//;
    $raw_content =~ s/\r\n/\n/g;
    $raw_content =~ s/\r/\n/g;
    $raw_content =~ s/^\s+//;

    my @parts = split(/^---\s*$/m, $raw_content);
    my %meta;
    my $body_block = "";

    if (scalar @parts >= 3) {
        my $meta_block = $parts[1];
        $body_block = join('---', @parts[2..$#parts]);
        $body_block =~ s/^\s+//;

        foreach my $line (split /\n/, $meta_block) {
            if ($line =~ /^\s*(\w+)\s*:\s*(.*)\s*$/) {
                my ($key, $val) = ($1, $2);
                $val =~ s/\s+$//;
                $meta{$key} = $val;
            }
        }
    } else {
        $body_block = $raw_content;
    }

    $meta{content} = $body_block;
    return \%meta;
}

sub render {
    my ($data, $is_tax, $path) = @_;
    
    $data->{slug} //= 'index';
    my $layout = $data->{layout} // 'page';
    my $tmpl_file = "$layout_dir/$layout.html";
    my $layout_content = -e $tmpl_file ? read_file_pure($tmpl_file) : read_file_pure("$layout_dir/page.html");
    
    $data->{current_page} = $is_tax ? "$path/$data->{slug}.html" : ($data->{slug} eq 'index' ? 'index.html' : "$data->{slug}.html");
    push @sitemap_urls, $data->{current_page};

    my $seo_tmpl = read_file_pure("$layout_dir/partials/seo.html");
    my $nav_tmpl = read_file_pure("$layout_dir/partials/nav.html");
    my $footer_tmpl = read_file_pure("$layout_dir/partials/footer.html");

    my $merged_data = { 
        %$config, 
        %$data,
        axcora_meta => qq|<meta name="brand" content="ONTA SSG"><meta name="architecture" content="Perl Driven, Static Site Architecture, Axcora Zetta Core Concept"><meta name="engine" content="Onta PERL SSG"><meta name="designer" content="Axcora Zetta Core + UI UX ccreativitas"><meta name="version" content="Onta V.1"><meta name="template-engine" content="Perl Custom Injector Engine">|,
        built_at => scalar(localtime)
    };

    my $seo = inject_data($seo_tmpl, $merged_data, $config, $path);
    my $nav = inject_data($nav_tmpl, $merged_data, $config, $path);
    my $footer = inject_data($footer_tmpl, $merged_data, $config, $path);
    my $body = inject_data($layout_content, $merged_data, $config, $path);

    my $final = inject_data(read_file_pure("$layout_dir/main.html"), { 
        %$merged_data,
        seo_tags => $seo, 
        nav => $nav, 
        footer => $footer, 
        main_content => $body 
    }, $config, $path);
    
    $final =~ s/\{\{\s*[^}]*\}\}//g;
    
    my $out = $is_tax ? "$pub/$path/$data->{slug}.html" : "$pub/$data->{slug}.html";
    write_file_pure($out, $final);
    
    print "  ${green}✔${reset} ${white}$out${reset}\n";
}



sub scan {
    my ($dir) = @_;
    opendir(my $dh, $dir) or return;
    while (my $f = readdir($dh)) {
        next if $f =~ /^[.]/;
        my $p = "$dir/$f";
        
        if (-d $p) {
            scan($p);
        }
        elsif ($f =~ /\.txt$/) {
            my $raw = read_file_pure($p);
            next if !$raw;

            my $d = get_meta($raw);
            my $name = basename($f, ".txt");
            
            $d->{slug} //= ($name eq 'home' ? 'index' : $name);
            $d->{title} //= ucfirst($d->{slug});

            my $rel_path = $dir;
            $rel_path =~ s/^\Q$content_dir\E\/?//;
            
            if ($rel_path eq '' && -d "$content_dir/$name") { next; }

            if ($rel_path ne '') {
                $d->{collection} = $rel_path;
                $d->{url_path} = "$rel_path/$d->{slug}.html";
                push @{$colls{$rel_path}}, $d;
                make_path("$pub/$rel_path");
                # render($d, 1, $rel_path);
            } else {
                $d->{collection} = undef;
                $d->{url_path} = "$d->{slug}.html";
                if ($d->{slug} !~ /^(index|tags|categories)$/) {
                    render($d, 0, undef);
                }
            }
            
            if ($d->{slug} ne 'index' && $rel_path ne '') {
                push @all_posts, $d;
            }

            if ($d->{category}) { 
                push @{$tax{category}->{slugify($d->{category})}}, $d; 
            }
            if ($d->{tags}) { 
                foreach (split(/\s*,\s*/, $d->{tags})) { 
                    push @{$tax{tag}->{slugify($_)}}, $d; 
                }
            }
        }
    }
    closedir($dh);
}

sub paginate {
    my ($items, $path, $title, $layout, $extra) = @_;
    my @sorted = sort { ($b->{date} // '') cmp ($a->{date} // '') } @$items;
    my $per = $config->{collections}->{$path}->{per_page} // 6;
    my $total = scalar @sorted;
    my $pages = int(($total - 1) / $per) + 1;

    for my $i (0 .. $pages - 1) {
        my $num = $i + 1;
        my @slice = @sorted[$i*$per .. (($i*$per+$per-1) < $total-1 ? ($i*$per+$per-1) : $total-1)];
        
        my $nums_html = "";
        for (1..$pages) { 
            my $act = ($_ == $num) ? "class='active'" : "";
            my $url = ($_ == 1) ? "index.html" : "page-$_.html";
            $nums_html .= "<li><a href='$url' $act>$_</a></li>"; 
        }

        render({
            %$extra,
            collection_title => $title,
            posts => \@slice,
            layout => $layout,
            slug => ($i == 0 ? "index" : "page-$num"),
            prev_page => ($num > 1 ? 1 : 0),
            next_page => ($num < $pages ? 1 : 0),
            prev_page_url => ($num == 2 ? "index.html" : "page-".($num-1).".html"),
            next_page_url => "page-".($num+1).".html",
            pagination_numbers => $nums_html
        }, 1, $path);
    }
}

if ($^O ne 'MSWin32') { system("clear"); }

clean_build();

print "\n${bold}${cyan}  ▲ ONTA SSG - by AXCORA ZETTA CORE ${reset}\n  ${blue}--------------------------------------------------${reset}\n";

dircopy("assets", "$pub/assets") if -d "assets";

scan($content_dir);

if (-e "$content_dir/tags.txt") {
    my $d = get_meta(read_file_pure("$content_dir/tags.txt"));
    $d->{slug} = 'tags';
    $d->{all_tags} = [ sort keys %{$tax{tag}} ]; 
    render($d, 0, undef);
}

if (-e "$content_dir/categories.txt") {
    my $d = get_meta(read_file_pure("$content_dir/categories.txt"));
    $d->{slug} = 'categories';
    $d->{all_categories} = [ sort keys %{$tax{category}} ];
    render($d, 0, undef);
}

foreach my $c (keys %colls) {
    next unless $c;
    my @posts = sort { ($b->{date} // '') cmp ($a->{date} // '') } @{$colls{$c}};

    for (my $i = 0; $i < scalar(@posts); $i++) {
        if ($i < $#posts) {
            $posts[$i]->{prev_url} = "/" . $posts[$i+1]->{url_path};
            $posts[$i]->{prev_title} = $posts[$i+1]->{title};
        }
        if ($i > 0) {
            $posts[$i]->{next_url} = "/" . $posts[$i-1]->{url_path};
            $posts[$i]->{next_title} = $posts[$i-1]->{title};
        }

        $posts[$i]->{collection_name} = ucfirst($c);
        $posts[$i]->{collection_slug} = $c;
        $posts[$i]->{layout} //= 'collections-post';
        
        render($posts[$i], 1, $c);
    }

    my $f = "$content_dir/$c.txt";
    my $m = -e $f ? get_meta(read_file_pure($f)) : {};
    
    $m->{collection_title} = $m->{title} // $m->{collection_title} // ucfirst($c);
    $m->{collection_description} = $m->{description} // $m->{collection_description} // "";
    $m->{layout} //= 'collections-list';

    paginate(\@posts, $c, $m->{collection_title}, $m->{layout}, $m);
}


foreach my $type (keys %tax) {
    make_path("$pub/$type");
    foreach my $term (keys %{$tax{$type}}) {
        my @posts = @{$tax{$type}->{$term}};
        
        render({ 
            title          => ucfirst($term),
            taxonomy_title => ucfirst($term),
            taxonomy_name  => ucfirst($term),
            taxonomy_type  => $type,
            posts          => \@posts,
            layout         => 'taxonomy_detail',
            slug           => $term,
            description    => "Browsing all posts filed under $term"
        }, 1, $type);
    }
}

my $home_file = "$content_dir/index.txt";
if (-e $home_file) {
    my $home = get_meta(read_file_pure($home_file));
    my @latest = sort { ($b->{date} // '') cmp ($a->{date} // '') } @all_posts;
    $home->{posts} = [ @latest[0..5] ];
    $home->{slug} = 'index';
    render($home, 0, undef);
}

generate_sitemap(\@sitemap_urls, $config->{site_info}->{url});
generate_robots($config->{site_info}->{url});


my $elapsed = tv_interval($start_time);

print "  ${blue}──────────────────────────────────────────────────${reset}\n";
printf "  ${blue}${reset}  ${bold}${green}🚀 DONE${reset}  Build completed in ${bold}${white}%.3fs${reset}         ${blue}${reset}\n", $elapsed;
print "  ${blue}──────────────────────────────────────────────────${reset}\n";
print "  ${blue}${reset}  ${bold}${cyan}📡 PREVIEW${reset}                                   ${blue}${reset}\n";
print "  ${blue}${reset}  URL: ${bold}${white}http://localhost:8000${reset}                  ${blue}${reset}\n";
print "  ${blue}${reset}                                                  ${blue}${reset}\n";
print "  ${blue}${reset}  ${bold}${white}COMMANDS TO RUN:${reset}                             ${blue}${reset}\n";
print "  ${blue}${reset}  ${cyan}•${reset} Python : python -m http.server 8000        ${blue}${reset}\n";
print "  ${blue}${reset}  ${cyan}•${reset} PHP    : php -S localhost:8000             ${blue}${reset}\n";
print "  ${blue}${reset}  ${cyan}•${reset} Node.js: npx serve                         ${blue}${reset}\n";
print "  ${blue}──────────────────────────────────────────────────${reset}\n\n";

print "  ${bold}${white}ONTA PERL SSG${reset}\n\n";
print "  ${bold}${white}By Axcora Zetta Core${reset} - ${cyan}www.axcora.com${reset}\n\n";

sub clean_build {
    my @whitelist = ('onta','style.html','push.pl','config.json','.git',
    '.htaccess','favicon.ico','ads.txt',
    'google987afd9113ba5a4a.html' , 'googlef8b9e33e9752d574.html' ,
    'onta.pl','assets','axcora_zeta_perl.css','README.md');
    my %protected = map { $_ => 1 } @whitelist;
    opendir(my $dh, $pub) or return;
    while (my $item = readdir($dh)) {
        next if $item =~ /^\.\.?$/;
        next if $protected{$item};
        my $full_path = "$pub/$item";
        if (-d $full_path) { remove_tree($full_path); }
        else { unlink($full_path); }
    }
    closedir($dh);
}