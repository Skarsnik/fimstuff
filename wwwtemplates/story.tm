% my (%h) = @_;
% my $story = %h<story>;
% my @dates = @(%h<dates>);
% my @maxcol = @(%h<maxcol>);
% my @data = @(%h<data>);
<h1><%= $story.title %></h1>
<table>
<tr>
<th></th>
% for @dates -> $date {
  <th><%= $date %></th>
% }
</tr>
% for @data.kv -> $i, @sdata {
  <tr>
  <td class="chapter-title"><%= $story.chapters[$i].title if $story.chapters[$i].defined %></td>
  % my $pos = 0;
  % for @sdata -> $pdata {
  <td>
    % if (@maxcol[$pos] and $pdata ne -1) {
      <div class="minigraph" style="width:<%= $pdata / @maxcol[$pos] * 100 %>%;">
      <%= $pdata %></div>
    % } else {
      <%= $pdata %>
    % }
  </td>
  % $pos++;
  % }
  <td class="chapter-title"><%= $story.chapters[$i].title if $story.chapters[$i].defined %></td>
  </tr>
% }
</table>
