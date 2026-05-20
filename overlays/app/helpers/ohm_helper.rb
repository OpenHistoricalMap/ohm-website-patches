module OhmHelper
  # OHM uses an active/secondary text-emphasis style for nav links instead of
  # the upstream icon-based secondary_nav_items helper.
  def header_nav_link_class(path)
    ["nav-link", current_page?(path) ? "active text-secondary-emphasis" : "text-secondary"]
  end

  # OHM ships its own RSS.png/RSS.svg, so override the upstream icon-based
  # rss_link_to and add an atom_link_to companion.
  def rss_link_to(args = {})
    link_to image_tag("RSS.png", :size => "16x16", :class => "align-text-bottom"), args
  end

  def atom_link_to(args = {})
    link_to image_tag("RSS.png", :size => "16x16", :class => "align-text-bottom"), args
  end
end
