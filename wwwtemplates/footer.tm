% my (%h) = @_;
% my $gtime = %h<gtime>;
% my $p6version = %h<p6version>;
% my $today = %h<today>;

<p class="gen_stats">This page was generated the <%= $today%> in <%= $gtime %> seconds with <%= $p6version %></p>
