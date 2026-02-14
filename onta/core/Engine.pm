use strict;
use warnings;

sub inject_data {
    my ($tmpl, $data, $config, $page_path) = @_;
    my $res = $tmpl;
    my $depth = $page_path ? scalar(split('/', $page_path)) : 0;
    my $page_base = $depth > 0 ? ('../' x $depth) : './';
    
    my $cat_slug = $data->{category} ? lc($data->{category}) : '';
    $cat_slug =~ s/[^a-z0-9]/-/g;
    
    my $tags_html = '';
    if ($data->{tags}) {
        foreach my $t (split(/\s*,\s*/, $data->{tags})) {
            my $t_slug = lc($t);
            $t_slug =~ s/[^a-z0-9]/-/g;
            $tags_html .= "<a href='${page_base}tag/$t_slug.html' class='axcora_perl_badge'>$t</a> ";
        }
    }

    my %all = (
        %$config,
        site_title       => $config->{site_info}->{title} // '',
        site_description => $config->{site_info}->{description} // '',
        %$data,
        description      => $data->{description} // $config->{site_info}->{description} // '',
        title            => $data->{title} // $config->{site_info}->{title} // '',
        site_url              => $config->{site_info}->{url} // '',
        favicon               => $config->{site_info}->{favicon} // '',
        image               => $config->{site_info}->{image} // '',
        navbar_title          => $config->{navbar}->{title} // '',
        navbar_button_text    => $config->{navbar}->{button}->{text} // '',
        navbar_button_url     => $config->{navbar}->{button}->{url} // '',
        footer_logo           => $config->{footer}->{logo} // '',
        footer_title          => $config->{footer}->{title} // '',
        footer_text           => $config->{footer}->{text} // '',
        copyrights            => $config->{footer}->{copyrights} // '',
        collection_title      => $data->{collection_title} // $data->{title} // '',
        collection_description => $data->{collection_description} // $data->{description} // '',
        taxonomy_title        => $data->{taxonomy_title} // $data->{title} // '',
        taxonomy_type         => $data->{taxonomy_type} // '',
        pagination_numbers    => $data->{pagination_numbers} // '',
        prev_page_url         => $data->{prev_page_url} // '',
        next_page_url         => $data->{next_page_url} // '',
        prev_title            => $data->{prev_title} // 'Previous Post',
        next_title            => $data->{next_title} // 'Next Post',
        menu1_title           => $config->{footer}->{menu1}->{title} // '',
        menu2_title           => $config->{footer}->{menu2}->{title} // '',
        category_slug         => $cat_slug,
        tags_links            => $tags_html,
        site_url              => $config->{url} // $config->{site_info}->{url} // '/',
        featured_image        => $data->{image} // $config->{site_info}->{image} // '',
    );
    
    my $m1 = '';
    my $menu1_data = $config->{footer}->{menu1}->{list};
    if ($menu1_data && ref($menu1_data) eq 'ARRAY') {
        foreach my $item (@$menu1_data) {
            my $url = $item->{url} // '#';
            $url = $url =~ /^http/ ? $url : $page_base . $url;
            my $name = $item->{nav} // 'Link';
            $m1 .= "<li><a href=\"$url\" class='text-white'>$name</a></li>";
        }
    }
    $all{menu1_links} = $m1;

    my $m2 = '';
    my $menu2_data = $config->{footer}->{menu2}->{list};
    if ($menu2_data && ref($menu2_data) eq 'ARRAY') {
        foreach my $item (@$menu2_data) {
            my $url = $item->{url} // '#';
            $url = $url =~ /^http/ ? $url : $page_base . $url;
            my $name = $item->{nav} // 'Link';
            $m2 .= "<li><a href=\"$url\" class='text-white'>$name</a></li>";
        }
    }
    $all{menu2_links} = $m2;
    
    my $html_out = '';

    # IF: Index Tags Page
    if ($data->{all_tags}) {
        foreach my $t (sort @{$data->{all_tags}}) {
            my $s = lc($t); $s =~ s/[^a-z0-9]/-/g;
            $html_out .= "<div class='axcora_perl_card' style='padding:30px; text-align:center;'><h3>$t</h3><a href='${page_base}tag/$s.html' class='axcora_perl_btn axcora_perl_btn_outline'>View Posts</a></div>";
        }
    }
    # ELSIF: Index Categories Page
    elsif ($data->{all_categories}) {
        foreach my $c (sort @{$data->{all_categories}}) {
            my $s = lc($c); $s =~ s/[^a-z0-9]/-/g;
            $html_out .= "<div class='axcora_perl_card' style='padding:30px; text-align:center;'><h3>$c</h3><a href='${page_base}category/$s.html' class='axcora_perl_btn axcora_perl_btn_outline'>View Posts</a></div>";
        }
    }
    # ELSIF: Detail Tag/Category (List of Posts)
    elsif ($data->{posts}) {
        foreach my $p (@{$data->{posts}}) {
            my $title = $p->{title} // 'Untitled';
            my $link  = $p->{url_path} // ($p->{slug} ? "$p->{slug}.html" : "#");
            my $img   = $p->{image} // '';
            my $date  = $p->{date} // '';
            my $img_html = $img ? "<img src='$page_base$img' class='axcora_perl_img_responsive' style='height:200px; width:100%; object-fit:cover;'>" : "";
            $html_out .= "<div class='axcora_perl_card'>$img_html<div class='axcora_perl_card_body'><small>$date</small><h3>$title</h3><a href='$page_base$link' class='axcora_perl_btn'>Read More</a></div></div>";
        }
    }

    $all{taxonomy_items} = $html_out;
    
    if ($data->{all_tags} && ref($data->{all_tags}) eq 'ARRAY') {
        my $html = '';
        foreach my $t (@{$data->{all_tags}}) {
            my $s = lc($t); $s =~ s/[^a-z0-9]/-/g;
            $html .= "<a href='${page_base}tag/$s.html' class='axcora_perl_badge'>$t</a> ";
        }
        $all{all_tags_list} = $html;
    }

    if ($data->{all_categories} && ref($data->{all_categories}) eq 'ARRAY') {
        my $html = '';
        foreach my $c (@{$data->{all_categories}}) {
            my $s = lc($c); $s =~ s/[^a-z0-9]/-/g;
            $html .= "<div class='axcora_perl_card' style='padding:30px; text-align:center;'>
                <h3 style='margin-bottom:15px;'>$c</h3>
                <a href='${page_base}category/$s.html' class='axcora_perl_btn axcora_perl_btn_outline'>View Posts</a>
            </div>";
        }
        $all{all_categories_list} = $html;
    }

    my $nav = '';
    if ($config->{navbar}->{list}) {
        foreach (@{$config->{navbar}->{list}}) {
            my $n_url = $_->{url} // '#';
            my $url = $n_url =~ /^http/ ? $n_url : $page_base . $n_url;
            $nav .= "<li><a href=\"$url\">" . ($_->{nav} // 'Link') . "</a></li>";
        }
    }
    $all{navbar_links} = $nav;
    
    my $posts_data = $data->{posts} // undef;
    my $html_result = '';

    if ($posts_data && ref($posts_data) eq 'ARRAY' && scalar(@$posts_data) > 0) {
        foreach my $p (@$posts_data) {
            my $title = $p->{title} // 'Untitled';
            my $link  = $p->{url_path} // ($p->{slug} ? "$p->{slug}.html" : "#");
            $link = "/$link" unless $link =~ /^\//;
            
            my $img   = $p->{image} // '';
            my $date  = $p->{date} // '';
            my $desc  = $p->{description} // '';
            
            if ($desc eq '' && $p->{content}) {
                $desc = substr($p->{content}, 0, 150);
                $desc =~ s/<[^>]*>//g; 
            }

            my $img_src = $img ? ($img =~ /^\// ? $img : "/$img") : '';
            my $img_html = $img 
                ? "<a href='$link'><img src='$img_src' loading='lazy' class='axcora_perl_img_responsive' style='height:200px; width:100%; object-fit:cover;' alt='$title'></a>"
                : "<div style='height:200px; background:#333; display:flex; align-items:center; justify-content:center; color:white;'>$title</div>";

            $html_result .= "
            <div class='axcora_perl_card'>
                $img_html
                <div class='axcora_perl_card_body p-5'>
                    <small class='axcora_perl_text_primary'>$date</small>
                    <h3 style='margin: 10px 0;'><a href='$link'>$title</a></h3>
                    <p style='font-size: 0.9rem; color: #666;'>$desc...</p>
                    <a href='$link' class='axcora_perl_btn axcora_perl_btn_primary' style='padding: 0.5rem 1rem; font-size: 0.8rem;'>Read $title</a>
                </div>
            </div>";
        }
    }
    
    $all{collection_items} = $html_result;
    $all{posts_list}       = $html_result;
    $all{taxonomy_items}   = $html_result;
    $all{blog_items}       = $html_result;
    if ($data->{all_tags} || $data->{all_categories}) {
        $all{taxonomy_items} = $html_out;
    } else {
        $all{taxonomy_items} = $html_result;
    }

    my $max_loop = 5;
    while ($res =~ /\[if:(!?)([^\]]+)\]/s && $max_loop--) {
        $res =~ s/\[if:(!?)([^\]]+)\](.*?)\[\/if\]/
            my ($not, $key, $inner) = ($1, $2, $3);
            my $val = $all{$key};
            my $ok = (defined $val && $val ne '' && $val ne '0') ? 1 : 0;
            $ok = !$ok if $not;
            $ok ? $inner : '';
        /sge;
    }

    foreach my $k (keys %all) {
        next if ref($all{$k});
        my $v = $all{$k} // '';
        $res =~ s/\{\{\s*\Q$k\E\s*\}\}/$v/g;
    }
    $res =~ s/!image\s+([^\s]+)\s+([^\s]+)/<div class="axcora_img_box"><img src="$2" alt="$1" class="axcora_perl_img_responsive" loading="lazy"><\/div>/g;
    $res =~ s/!\[([^\]]*)\]\(([^\)]+)\)/<div class="axcora_img_box"><img src="$2" alt="$1" class="axcora_perl_img_responsive" loading="lazy"><\/div>/g;
    $res =~ s{(href|src|content)=(['"])/}{$1=$2$page_base}g;
    $res =~ s/\[([^\]]+)\]\(([^)]+)\)/<a href="$2">$1<\/a>/g;
    $res =~ s/\*\*([^*]+)\*\*/<strong>$1<\/strong>/g;
    $res =~ s/^\s*###\s*(.*)$/<h3>$1<\/h3>/gm;
    $res =~ s/^\s*##\s*(.*)$/<h2>$1<\/h2>/gm;
    $res =~ s/^\s*#\s*(.*)$/<h1>$1<\/h1>/gm;
    $res =~ s/^\s*\d+\.\s*(.*)$/<div style="display:list-item;list-style-type:decimal;margin-left:30px;">$1<\/div>/gm;
    $res =~ s/^\s*\*\s*(.*)$/<div style="display:list-item;list-style-type:disc;margin-left:30px;">$1<\/div>/gm;
    $res =~ s/^\s*\d+\.\s*(.*)$/<li>$1<\/li>/gm;
    $res =~ s/^\s*\*\s*(.*)$/<li>$1<\/li>/gm;
    $res =~ s/^\s*>\s*(.*)$/<blockquote>$1<\/blockquote>/gm;
    $res =~ s/```(?:[a-z]+)?\n?(.*?)```/<pre><code>$1<\/code><\/pre>/gs;
    $res =~ s/<iframe(.*?)><\/iframe>/<div class="video-container"><iframe$1><\/iframe><\/div>/gs;
    $res =~ s/`([^`]+)`/<code>$1<\/code>/g;
    return $res;
}

1;