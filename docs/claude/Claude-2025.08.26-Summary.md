# Redmine README Plugin Compatibility Fix Summary

- **Date**: August 26, 2025, 22:15 JST
- **Model**: `claude-sonnet-4-20250514`

## Problem Statement

A Redmine plugin called `readme_at_repositories` that displays `README.md` files in repository pages stopped working
after upgrading from Redmine 5.0.x/5.1.x to Redmine 6.0.4. The plugin was still showing README files, but Markdown
formatting was not being applied - files were displayed as plain text instead of rendered HTML.

**Environment Details:**

- Redmine version: `6.0.4.stable`
- Ruby version: `3.3.7-p123 (2025-01-15) [x86_64-linux]`
- Rails version: `7.2.2.1`

## Initial Investigation and Assumptions

### Phase 1: Rails/Ruby Compatibility Issues

Initially assumed the problem was related to deprecated Rails/Ruby methods that were removed in newer versions.

**Issues Identified:**

1. `require_dependency` was deprecated in Rails 7
2. `unloadable` was obsolete since Rails 5+
3. Missing `alias_method_chain` implementation
4. Deprecated HTML encoding methods in view templates

**Changes Made:**

- Replaced `require_dependency` with `require` in `init.rb` and `lib` files
- Removed obsolete `unloadable` call
- Implemented manual `alias_method_chain` functionality using `alias_method`
- Simplified HTML encoding in view template

**Result:** Fixed basic compatibility issues, but Markdown formatting still not working.

### Phase 2: Encoding Problems

After applying Rails/Ruby fixes, encountered a 500 error with encoding incompatibility between ASCII-8BIT and UTF-8.

**Issue Identified:**
The `repo.cat()` method returns raw bytes (ASCII-8BIT encoding) but the formatter expects UTF-8.

**Change Made:**
Added `raw_readme_text.force_encoding('UTF-8')` to force proper encoding.

**Result:** Fixed the 500 error, repository pages loaded, but Markdown still displayed as plain text.

### Phase 3: Formatter Detection Issues

Suspected that the Markdown formatter detection logic wasn't working properly in Redmine 6.0.

**Approaches Tried:**

1. Enhanced formatter detection with multiple fallback methods
2. Added error handling for missing formatters
3. Tested various formatter names (`markdown`, `common_mark`, `redcarpet`)
4. Implemented fallback to default Textile formatter

**Result:** Still no Markdown rendering - indicating the problem was more fundamental.

## Final Solution: Native Redmine Approach

### Root Cause Analysis

Analyzed Redmine 6.0.x source code directly from GitHub to understand how it natively renders Markdown files in
repositories. Discovered that the plugin was using an outdated approach for Markdown rendering.

### Key Insights from Redmine Source Code

1. Redmine uses `Redmine::WikiFormatting.to_html(format, content)` instead of creating formatter instances
2. For Markdown files, Redmine uses `'common_mark'` as the format parameter
3. Content encoding is handled via `Redmine::CodesetUtil.to_utf8_by_setting()`
4. The approach mirrors exactly what's done in `app/views/repositories/entry.html.erb` and
   `app/views/common/_markup.html.erb`

### Final Code Changes

**Original Problematic Code (`lib/display_readme.rb`):**

```ruby
# Force encoding to UTF-8 to prevent ASCII-8BIT/UTF-8 compatibility errors
raw_readme_text = raw_readme_text.force_encoding('UTF-8')

formatter_name = ''
if @@markdown_ext.include?(File.extname(file.path))
  # Try to find available Markdown formatter in Redmine 6.0
  available_formats = Redmine::WikiFormatting.format_names
  formatter_name = available_formats.find { |name| name =~ /markdown/i } ||
                  available_formats.find { |name| name.downcase.include?('markdown') }
  
  # In Redmine 6.0, try common markdown formatter names
  unless formatter_name
    ['markdown', 'common_mark', 'redcarpet'].each do |name|
      begin
        if Redmine::WikiFormatting.formatter_for(name)
          formatter_name = name
          break
        end
      rescue
        next
      end
    end
  end
end

# Use default formatter (textile) if no markdown formatter found
formatter_name ||= ''

begin
  formatter = Redmine::WikiFormatting.formatter_for(formatter_name).new(raw_readme_text)
rescue => e
  # Fallback to default formatter if there's any error
  formatter = Redmine::WikiFormatting.formatter_for('').new(raw_readme_text)
end

# Later in render_to_string call:
:locals => {:html => formatter.to_html, ...}
```

**Final Working Code (`lib/display_readme.rb`):**

```ruby
# Use Redmine's native approach to render content like in repositories/entry.html.erb
formatter_name = ''
if @@markdown_ext.include?(File.extname(file.path))
  formatter_name = 'common_mark'
end

# Convert content using Redmine's native WikiFormatting with proper encoding
formatted_html = Redmine::WikiFormatting.to_html(formatter_name, Redmine::CodesetUtil.to_utf8_by_setting(raw_readme_text))

# Later in render_to_string call:
:locals => {:html => formatted_html, ...}
```

### Key Differences in Final Solution

1. **Method Change**: Replaced `Redmine::WikiFormatting.formatter_for(name).new(content).to_html` with
   `Redmine::WikiFormatting.to_html(format, content)`

2. **Encoding Handling**: Used Redmine's native `Redmine::CodesetUtil.to_utf8_by_setting()` instead of manual
   `force_encoding('UTF-8')`

3. **Format Parameter**: Directly used `'common_mark'` string instead of complex formatter detection logic

4. **Simplified Logic**: Removed all error handling and fallback mechanisms since we're using Redmine's proven native
   approach

## Resolution

The final solution successfully restored Markdown formatting by adopting Redmine 6.0's native approach to file
rendering. The plugin now displays README.md files with proper Markdown formatting, exactly like Redmine does when
viewing files directly in the repository browser.

**Root Cause**: The plugin was using an outdated API approach that was either deprecated or changed in Redmine 6.0,
while Redmine itself had moved to a different internal API for rendering markup content.

**Key Lesson**: When debugging compatibility issues with framework upgrades, analyzing how the framework itself handles
similar functionality internally can reveal the correct modern approach, rather than trying to fix the old approach with
workarounds.
