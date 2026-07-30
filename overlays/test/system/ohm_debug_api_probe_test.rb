# frozen_string_literal: true

# TEMPORARY debug probe for IndexTest#test_node_included_in_edit_link.
# Prints what the browser actually receives from /api/0.6/node/:id so we can
# see why leaflet.map.js addObject hits a JSON.parse error in CI.
# Delete this file once the editanchor failure is understood.

require "application_system_test_case"

class OhmDebugApiProbeTest < ApplicationSystemTestCase
  test "api node fetch body probe" do
    node = create(:node)
    visit node_path(node)

    body = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      fetch("/api/0.6/node/#{node.id}", { headers: { accept: "application/json" } })
        .then(r => r.text().then(t => done({ status: r.status, contentType: r.headers.get("content-type"), body: t.slice(0, 300) })))
        .catch(e => done({ error: String(e) }));
    JS

    puts "OHM_DEBUG_API_PROBE: #{body.inspect}"

    editanchor = page.evaluate_script("document.querySelector('#editanchor')?.outerHTML?.slice(0, 300)")
    puts "OHM_DEBUG_EDITANCHOR: #{editanchor.inspect}"

    status = page.evaluate_script("document.querySelector('#browse_status')?.textContent?.slice(0, 300)")
    puts "OHM_DEBUG_BROWSE_STATUS: #{status.inspect}"

    assert true
  end
end
