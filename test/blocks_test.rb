require 'test_helper'
require 'pathname'

context "Blocks" do
  context 'Line Breaks' do
    test "ruler" do
      output = render_string("'''")
      assert_xpath '//*[@id="content"]/hr', output, 1
      assert_xpath '//*[@id="content"]/*', output, 1
    end

    test "ruler between blocks" do
      output = render_string("Block above\n\n'''\n\nBlock below")
      assert_xpath '//*[@id="content"]/hr', output, 1
      assert_xpath '//*[@id="content"]/hr/preceding-sibling::*', output, 1
      assert_xpath '//*[@id="content"]/hr/following-sibling::*', output, 1
    end

    test "page break" do
      output = render_embedded_string("page 1\n\n<<<\n\npage 2")
      assert_xpath '/*[@style="page-break-after: always;"]', output, 1
      assert_xpath '/*[@style="page-break-after: always;"]/preceding-sibling::div/p[text()="page 1"]', output, 1
      assert_xpath '/*[@style="page-break-after: always;"]/following-sibling::div/p[text()="page 2"]', output, 1
    end
  end

  context 'Comments' do
    test 'line comment between paragraphs offset by blank lines' do
      input = <<-EOS
first paragraph

// line comment

second paragraph
      EOS
      output = render_embedded_string input
      assert_no_match(/line comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent line comment between paragraphs' do
      input = <<-EOS
first line
// line comment
second line
      EOS
      output = render_embedded_string input
      assert_no_match(/line comment/, output)
      assert_xpath '//p', output, 1
      assert_xpath "//p[1][text()='first line\nsecond line']", output, 1
    end

    test 'comment block between paragraphs offset by blank lines' do
      input = <<-EOS
first paragraph

////
block comment
////

second paragraph
      EOS
      output = render_embedded_string input
      assert_no_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test 'adjacent comment block between paragraphs' do
      input = <<-EOS
first paragraph
////
block comment
////
second paragraph
      EOS
      output = render_embedded_string input
      assert_no_match(/block comment/, output)
      assert_xpath '//p', output, 2
    end

    test "can render with block comment at end of document with trailing endlines" do
      input = <<-EOS
paragraph

////
block comment
////


      EOS
      output = render_embedded_string input
      assert_no_match(/block comment/, output)
    end

    test "trailing endlines after block comment at end of document does not create paragraph" do
      input = <<-EOS
paragraph

////
block comment
////


      EOS
      d = document_from_string input
      assert_equal 1, d.blocks.size
      assert_xpath '//p', d.render, 1
    end

    test 'line starting with three slashes should not be line comment' do
      input = <<-EOS
/// not a line comment
      EOS

      output = render_embedded_string input
      assert !output.strip.empty?, "Line should be emitted => #{input.rstrip}"
    end
  end

  context "Example Blocks" do
    test "can render example block" do
      input = <<-EOS
====
This is an example of an example block.

How crazy is that?
====
      EOS

      output = render_string input
      assert_xpath '//*[@class="exampleblock"]//p', output, 2
    end

    test "assigns sequential numbered caption to example block with title" do
      input = <<-EOS
.Writing Docs with AsciiDoc
====
Here's how you write AsciiDoc.

You just write.
====

.Writing Docs with DocBook
====
Here's how you write DocBook.

You futz with XML.
====
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example 1. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example 2. Writing Docs with DocBook"]', output, 1
      assert_equal 2, doc.attributes['example-number']
    end

    test "assigns sequential character caption to example block with title" do
      input = <<-EOS
:example-number: @

.Writing Docs with AsciiDoc
====
Here's how you write AsciiDoc.

You just write.
====

.Writing Docs with DocBook
====
Here's how you write DocBook.

You futz with XML.
====
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Example A. Writing Docs with AsciiDoc"]', output, 1
      assert_xpath '(//*[@class="exampleblock"])[2]/*[@class="title"][text()="Example B. Writing Docs with DocBook"]', output, 1
      assert_equal 'B', doc.attributes['example-number']
    end

    test "explicit caption is used if provided" do
      input = <<-EOS
[caption="Look! "]
.Writing Docs with AsciiDoc
====
Here's how you write AsciiDoc.

You just write.
====
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '(//*[@class="exampleblock"])[1]/*[@class="title"][text()="Look! Writing Docs with AsciiDoc"]', output, 1
      assert !doc.attributes.has_key?('example-number')
    end

    test 'automatic caption can be turned off and on and modified' do
      input = <<-EOS
.first example
====
an example
====

:caption:

.second example
====
another example
====

:caption!:
:example-caption: Exhibit

.third example
====
yet another example
====
      EOS

      output = render_embedded_string input
      assert_xpath '/*[@class="exampleblock"]', output, 3
      assert_xpath '(/*[@class="exampleblock"])[1]/*[@class="title"][starts-with(text(), "Example ")]', output, 1
      assert_xpath '(/*[@class="exampleblock"])[2]/*[@class="title"][text()="second example"]', output, 1
      assert_xpath '(/*[@class="exampleblock"])[3]/*[@class="title"][starts-with(text(), "Exhibit ")]', output, 1
    end
  end

  context 'Admonition Blocks' do
    test 'caption block-level attribute should be used as caption' do
       input = <<-EOS
:tip-caption: Pro Tip

[caption="Pro Tip"]
TIP: Override the caption of an admonition block using an attribute entry
       EOS

       output = render_embedded_string input
       assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Pro Tip"]', output, 1
    end

    test 'can override caption of admonition block using document attribute' do
       input = <<-EOS
:tip-caption: Pro Tip

TIP: Override the caption of an admonition block using an attribute entry
       EOS

       output = render_embedded_string input
       assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Pro Tip"]', output, 1
    end

    test 'blank caption document attribute should not blank admonition block caption' do
       input = <<-EOS
:caption:

TIP: Override the caption of an admonition block using an attribute entry
       EOS

       output = render_embedded_string input
       assert_xpath '/*[@class="admonitionblock tip"]//*[@class="icon"]/*[@class="title"][text()="Tip"]', output, 1
    end
  end

  context "Preformatted Blocks" do
    test 'should separate adjacent paragraphs and listing into blocks' do
      input = <<-EOS
paragraph 1
----
listing content
----
paragraph 2
      EOS
      
      output = render_embedded_string input
      assert_xpath '/*[@class="paragraph"]/p', output, 2
      assert_xpath '/*[@class="listingblock"]', output, 1
      assert_xpath '(/*[@class="paragraph"]/following-sibling::*)[1][@class="listingblock"]', output, 1
    end

    test "should preserve endlines in literal block" do
      input = <<-EOS
....
line one

line two

line three
....
EOS
      [true, false].each {|compact|
        output = render_string input, :compact => compact
        assert_xpath '//pre', output, 1
        assert_xpath '//pre/text()', output, 1
        text = xmlnodes_at_xpath('//pre/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[[:blank:]]*\n/).size
        if compact
          assert_equal 2, blank_lines
        else
          assert blank_lines > 2
        end
      }
    end

    test "should preserve endlines in listing block" do
      input = <<-EOS
[source]
----
line one

line two

line three
----
EOS
      [true, false].each {|compact|
        output = render_string input, :compact => compact
        assert_xpath '//pre/code', output, 1
        assert_xpath '//pre/code/text()', output, 1
        text = xmlnodes_at_xpath('//pre/code/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[[:blank:]]*\n/).size
        if compact
          assert_equal 2, blank_lines
        else
          assert blank_lines > 2
        end
      }
    end

    test "should preserve endlines in verse block" do
      input = <<-EOS
[verse]
____
line one

line two

line three
____
EOS
      [true, false].each {|compact|
        output = render_string input, :compact => compact
        assert_xpath '//*[@class="verseblock"]/pre', output, 1
        assert_xpath '//*[@class="verseblock"]/pre/text()', output, 1
        text = xmlnodes_at_xpath('//*[@class="verseblock"]/pre/text()', output, 1).text
        lines = text.lines.entries
        assert_equal 5, lines.size
        expected = "line one\n\nline two\n\nline three".lines.entries
        assert_equal expected, lines
        blank_lines = output.scan(/\n[[:blank:]]*\n/).size
        if compact
          assert_equal 2, blank_lines
        else
          assert blank_lines > 2
        end
      }
    end

    test 'should not compact nested document twice' do
      input = <<-EOS
|===
a|....
line one

line two

line three
....
|===
      EOS

      output = render_string input, :compact => true
      assert_xpath %(//pre[text() = "line one\n\nline two\n\nline three"]), output, 1
    end

    test 'should process block with CRLF endlines' do
      input = <<-EOS
[source]\r
----\r
source line 1\r
source line 2\r
----\r
      EOS

      output = render_embedded_string input
      assert_no_match(/\[source\]/, output)
      assert_xpath '/*[@class="listingblock"]//pre', output, 1
      assert_xpath '/*[@class="listingblock"]//pre/code', output, 1
      assert_xpath %(/*[@class="listingblock"]//pre/code[text()="source line 1\nsource line 2"]), output, 1
    end

    test 'literal block should honor explicit subs list' do
      input = <<-EOS
[subs="verbatim,quotes"]
----
Map<String, String> *attributes*; //<1>
----
      EOS

      output = render_embedded_string input
      assert output.include?('Map&lt;String, String&gt; <strong>attributes</strong>;')
      assert output.include?('1')
    end

    test 'listing block should honor explicit subs list' do
      input = <<-EOS
[subs="specialcharacters,quotes"]
----
$ *python functional_tests.py*
Traceback (most recent call last):
  File "functional_tests.py", line 4, in <module>
    assert 'Django' in browser.title
AssertionError
----
      EOS

      output = render_embedded_string input

      assert_css '.listingblock pre', output, 1
      assert_css '.listingblock pre strong', output, 1
      assert_css '.listingblock pre em', output, 1

      input2 = <<-EOS
[subs="specialcharacters,macros"]
----
$ pass:quotes[*python functional_tests.py*]
Traceback (most recent call last):
  File "functional_tests.py", line 4, in <module>
    assert pass:quotes['Django'] in browser.title
AssertionError
----
      EOS

      output2 = render_embedded_string input2
      # FIXME JRuby is adding extra trailing endlines in the second document,
      # so rstrip is necessary
      assert_equal output.rstrip, output2.rstrip
    end
  end

  context "Open Blocks" do
    test "can render open block" do
      input = <<-EOS
--
This is an open block.

It can span multiple lines.
--
      EOS

      output = render_string input
      assert_xpath '//*[@class="openblock"]//p', output, 2
    end

    test "open block can contain another block" do
      input = <<-EOS
--
This is an open block.

It can span multiple lines.

____
It can hold great quotes like this one.
____
--
      EOS

      output = render_string input
      assert_xpath '//*[@class="openblock"]//p', output, 3
      assert_xpath '//*[@class="openblock"]//*[@class="quoteblock"]', output, 1
    end
  end

  context 'Passthrough Blocks' do
    test 'can parse a passthrough block' do
      input = <<-EOS
++++
This is a passthrough block.
++++
      EOS

      block = block_from_string input
      assert !block.nil?
      assert_equal 1, block.buffer.size
      assert_equal 'This is a passthrough block.', block.buffer.first
    end

    test 'performs passthrough subs on a passthrough block' do
      input = <<-EOS
:type: passthrough

++++
This is a '{type}' block.
http://asciidoc.org
++++
      EOS

      expected = %(This is a 'passthrough' block.\n<a href="http://asciidoc.org">http://asciidoc.org</a>)
      output = render_embedded_string input
      assert_equal expected, output.strip
    end

    test 'passthrough block honors explicit subs list' do
      input = <<-EOS
:type: passthrough

[subs="attributes, quotes"]
++++
This is a '{type}' block.
http://asciidoc.org
++++
      EOS

      expected = %(This is a <em>passthrough</em> block.\nhttp://asciidoc.org)
      output = render_embedded_string input
      assert_equal expected, output.strip
    end
  end

  context 'Metadata' do
    test 'block title above section gets carried over to first block in section' do
      input = <<-EOS
.Title
== Section

paragraph
      EOS
      output = render_string input
      assert_xpath '//*[@class="paragraph"]', output, 1
      assert_xpath '//*[@class="paragraph"]/*[@class="title"][text() = "Title"]', output, 1
      assert_xpath '//*[@class="paragraph"]/p[text() = "paragraph"]', output, 1
    end

    test 'block title above document title gets carried over to preamble' do
      input = <<-EOS
.Block title
= Document Title

preamble
      EOS
      output = render_string input
      assert_xpath '//*[@id="preamble"]//*[@class="paragraph"]/*[@class="title"][text()="Block title"]', output, 1
    end

    test 'block title above document title gets carried over to first block in first section if no preamble' do
      input = <<-EOS
.Block title
= Document Title

== First Section 

paragraph
      EOS
      output = render_string input
      assert_xpath '//*[@class="sect1"]//*[@class="paragraph"]/*[@class="title"][text() = "Block title"]', output, 1
    end

    test 'empty attribute list should not appear in output' do
      input = <<-EOS
[]
--
Block content
--
      EOS

      output = render_embedded_string input
      assert output.include?('Block content')
      assert !output.include?('[]')
    end

    test 'empty block anchor should not appear in output' do
      input = <<-EOS
[[]]
--
Block content
--
      EOS

      output = render_embedded_string input
      assert output.include?('Block content')
      assert !output.include?('[[]]')
    end
  end

  context 'Images' do
    test 'can render block image with alt text defined in macro' do
      input = <<-EOS
image::images/tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'can render block image with alt text defined in macro containing escaped square bracket' do
      input = <<-EOS
image::images/tiger.png[A [Bengal\\] Tiger]
      EOS

      output = render_string input
      img = xmlnodes_at_xpath '//img', output, 1
      assert_equal 'A [Bengal] Tiger', img.attr('alt').value
    end

    test 'can render block image with alt text defined in block attribute above macro' do
      input = <<-EOS
[Tiger]
image::images/tiger.png[]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'alt text in macro overrides alt text above macro' do
      input = <<-EOS
[Alt Text]
image::images/tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test "can render block image with auto-generated alt text" do
      input = <<-EOS
image::images/tiger.png[]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="tiger"]', output, 1
    end

    test "can render block image with alt text and height and width" do
      input = <<-EOS
image::images/tiger.png[Tiger, 200, 300]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"][@width="200"][@height="300"]', output, 1
    end

    test "can render block image with link" do
      input = <<-EOS
image::images/tiger.png[Tiger, link='http://en.wikipedia.org/wiki/Tiger']
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//a[@class="image"][@href="http://en.wikipedia.org/wiki/Tiger"]/img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test "can render block image with caption" do
      input = <<-EOS
.The AsciiDoc Tiger
image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text() = "Figure 1. The AsciiDoc Tiger"]', output, 1
      assert_equal 1, doc.attributes['figure-number']
    end

    test 'can render block image with explicit caption' do
      input = <<-EOS
[caption="Voila! "]
.The AsciiDoc Tiger
image::images/tiger.png[Tiger]
      EOS

      doc = document_from_string input
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
      assert_xpath '//*[@class="imageblock"]/*[@class="title"][text() = "Voila! The AsciiDoc Tiger"]', output, 1
      assert !doc.attributes.has_key?('figure-number')
    end

    test 'drops line if image target is missing attribute reference' do
      input = <<-EOS
image::{bogus}[]
      EOS

      output = render_embedded_string input
      assert output.strip.empty?
    end

    test 'dropped image does not break processing of following section' do
      input = <<-EOS
image::{bogus}[]

== Section Title
      EOS

      output = render_embedded_string input
      assert_css 'img', output, 0
      assert_css 'h2', output, 1 
      assert !output.include?('== Section Title')
    end

    test 'should pass through image that references uri' do
      input = <<-EOS
:imagesdir: images

image::http://asciidoc.org/images/tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="http://asciidoc.org/images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'can resolve image relative to imagesdir' do
      input = <<-EOS
:imagesdir: images

image::tiger.png[Tiger]
      EOS

      output = render_string input
      assert_xpath '//*[@class="imageblock"]//img[@src="images/tiger.png"][@alt="Tiger"]', output, 1
    end

    test 'embeds base64-encoded data uri for image when data-uri attribute is set' do
      input = <<-EOS
:data-uri:
:imagesdir: fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal 'fixtures', doc.attributes['imagesdir']
      output = doc.render
      assert_xpath '//*[@class="imageblock"]//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    # this test will cause a warning to be printed to the console (until we have a message facility)
    test 'cleans reference to ancestor directories in imagesdir before reading image if safe mode level is at least SAFE' do
      input = <<-EOS
:data-uri:
:imagesdir: ../..//fixtures/./../../fixtures

image::dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal '../..//fixtures/./../../fixtures', doc.attributes['imagesdir']
      output = doc.render
      # image target resolves to fixtures/dot.gif relative to docdir (which is explicitly set to the directory of this file)
      # the reference cannot fall outside of the document directory in safe mode
      assert_xpath '//*[@class="imageblock"]//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end

    test 'cleans reference to ancestor directories in target before reading image if safe mode level is at least SAFE' do
      input = <<-EOS
:data-uri:
:imagesdir: ./

image::../..//fixtures/./../../fixtures/dot.gif[Dot]
      EOS

      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_equal './', doc.attributes['imagesdir']
      output = doc.render
      # image target resolves to fixtures/dot.gif relative to docdir (which is explicitly set to the directory of this file)
      # the reference cannot fall outside of the document directory in safe mode
      assert_xpath '//*[@class="imageblock"]//img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Dot"]', output, 1
    end
  end

  context 'Media' do
    test 'should detect and render video macro' do
      input = <<-EOS
video::cats-vs-dogs.avi[]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
    end

    test 'should detect and render video macro with positional attributes for poster and dimensions' do
      input = <<-EOS
video::cats-vs-dogs.avi[cats-and-dogs.png, 200, 300]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="cats-vs-dogs.avi"]', output, 1
      assert_css 'video[poster="cats-and-dogs.png"]', output, 1
      assert_css 'video[width="200"]', output, 1
      assert_css 'video[height="300"]', output, 1
    end

    test 'video macro should honor all options' do
      input = <<-EOS
video::cats-vs-dogs.avi[options="autoplay,nocontrols,loop"]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[autoplay]', output, 1
      assert_css 'video:not([controls])', output, 1
      assert_css 'video[loop]', output, 1
    end

    test 'video macro should use imagesdir attribute to resolve target and poster' do
      input = <<-EOS
:imagesdir: assets

video::cats-vs-dogs.avi[cats-and-dogs.png, 200, 300]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="assets/cats-vs-dogs.avi"]', output, 1
      assert_css 'video[poster="assets/cats-and-dogs.png"]', output, 1
      assert_css 'video[width="200"]', output, 1
      assert_css 'video[height="300"]', output, 1
    end

    test 'video macro should not use imagesdir attribute to resolve target if target is a URL' do
      input = <<-EOS
:imagesdir: assets

video::http://example.org/videos/cats-vs-dogs.avi[]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="http://example.org/videos/cats-vs-dogs.avi"]', output, 1
    end

    test 'should detect and render audio macro' do
      input = <<-EOS
audio::podcast.mp3[]
      EOS

      output = render_embedded_string input
      assert_css 'audio', output, 1
      assert_css 'audio[src="podcast.mp3"]', output, 1
    end

    test 'audio macro should use imagesdir attribute to resolve target' do
      input = <<-EOS
:imagesdir: assets

audio::podcast.mp3[]
      EOS

      output = render_embedded_string input
      assert_css 'audio', output, 1
      assert_css 'audio[src="assets/podcast.mp3"]', output, 1
    end

    test 'audio macro should not use imagesdir attribute to resolve target if target is a URL' do
      input = <<-EOS
:imagesdir: assets

video::http://example.org/podcast.mp3[]
      EOS

      output = render_embedded_string input
      assert_css 'video', output, 1
      assert_css 'video[src="http://example.org/podcast.mp3"]', output, 1
    end

    test 'audio macro should honor all options' do
      input = <<-EOS
audio::podcast.mp3[options="autoplay,nocontrols,loop"]
      EOS

      output = render_embedded_string input
      assert_css 'audio', output, 1
      assert_css 'audio[autoplay]', output, 1
      assert_css 'audio:not([controls])', output, 1
      assert_css 'audio[loop]', output, 1
    end
  end

  context 'Admonition icons' do
    test 'can resolve icon relative to default iconsdir' do
      input = <<-EOS
:icons:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="./images/icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'can resolve icon relative to custom iconsdir' do
      input = <<-EOS
:icons:
:iconsdir: icons

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="icons/tip.png"][@alt="Tip"]', output, 1
    end

    test 'embeds base64-encoded data uri of icon when data-uri attribute is set and safe mode level is less than SECURE' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:icontype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end

    test 'does not embed base64-encoded data uri of icon when safe mode level is SECURE or greater' do
      input = <<-EOS
:icons:
:iconsdir: fixtures
:icontype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :attributes => {'icons' => ''}
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="fixtures/tip.gif"][@alt="Tip"]', output, 1
    end

    test 'cleans reference to ancestor directories before reading icon if safe mode level is at least SAFE' do
      input = <<-EOS
:icons:
:iconsdir: ../fixtures
:icontype: gif
:data-uri:

[TIP]
You can use icons for admonitions by setting the 'icons' attribute.
      EOS

      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE, :attributes => {'docdir' => File.dirname(__FILE__)}
      assert_xpath '//*[@class="admonitionblock tip"]//*[@class="icon"]/img[@src="data:image/gif;base64,R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="][@alt="Tip"]', output, 1
    end
  end

  context 'Image paths' do

    test 'restricts access to ancestor directories when safe mode level is at least SAFE' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.expand_path File.dirname(__FILE__)
      block = block_from_string input, :attributes => {'docdir' => basedir}
      doc = block.document
      assert doc.safe >= Asciidoctor::SafeMode::SAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      assert_equal File.join(basedir, 'etc/images'), block.normalize_asset_path("#{disk_root}etc/images")
      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('../../images')
    end

    test 'does not restrict access to ancestor directories when safe mode is disabled' do
      input = <<-EOS
image::asciidoctor.png[Asciidoctor]
      EOS
      basedir = File.expand_path File.dirname(__FILE__)
      block = block_from_string input, :safe => Asciidoctor::SafeMode::UNSAFE, :attributes => {'docdir' => basedir}
      doc = block.document
      assert doc.safe == Asciidoctor::SafeMode::UNSAFE

      assert_equal File.join(basedir, 'images'), block.normalize_asset_path('images')
      absolute_path = "#{disk_root}etc/images"
      assert_equal absolute_path, block.normalize_asset_path(absolute_path)
      assert_equal File.expand_path(File.join(basedir, '../../images')), block.normalize_asset_path('../../images')
    end

  end

  context 'Source code' do
    test 'should support fenced code block using backticks' do
      input = <<-EOS
```
puts "Hello, World!"
```
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 1
      assert_css '.listingblock pre code', output, 1
      assert_css '.listingblock pre code:not([class])', output, 1
    end

    test 'should support fenced code block using tildes' do
      input = <<-EOS
~~~
puts "Hello, World!"
~~~
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 1
      assert_css '.listingblock pre code', output, 1
      assert_css '.listingblock pre code:not([class])', output, 1
    end

    test 'should support fenced code blocks with languages' do
      input = <<-EOS
```ruby
puts "Hello, World!"
```

~~~ javascript
alert("Hello, World!")
~~~
      EOS

      output = render_embedded_string input
      assert_css '.listingblock', output, 2
      assert_css '.listingblock pre code.ruby', output, 1
      assert_css '.listingblock pre code.javascript', output, 1
    end

    test 'should highlight source if source-highlighter attribute is coderay' do
      input = <<-EOS
:source-highlighter: coderay

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_xpath '//pre[@class="highlight CodeRay"]/code[@class="ruby"]//span[@class = "constant"][text() = "CodeRay"]', output, 1
      assert_match(/\.CodeRay \{/, output)
    end

    test 'should highlight source inline if source-highlighter attribute is coderay and coderay-css is style' do
      input = <<-EOS
:source-highlighter: coderay
:coderay-css: style

[source, ruby]
----
require 'coderay'

html = CodeRay.scan("puts 'Hello, world!'", :ruby).div(:line_numbers => :table)
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_xpath '//pre[@class="highlight CodeRay"]/code[@class="ruby"]//span[@style = "color:#036;font-weight:bold"][text() = "CodeRay"]', output, 1
      assert_no_match(/\.CodeRay \{/, output)
    end

    test 'should include remote highlight.js assets if source-highlighter attribute is highlightjs' do
      input = <<-EOS
:source-highlighter: highlightjs

[source, javascript]
----
<link rel="stylesheet" href="styles/default.css">
<script src="highlight.pack.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
----
      EOS
      output = render_string input, :safe => Asciidoctor::SafeMode::SAFE
      assert_match(/<link .*highlight\.js/, output)
      assert_match(/<script .*highlight\.js/, output)
      assert_match(/hljs.initHighlightingOnLoad/, output)
    end

    test 'document cannot turn on source highlighting if safe mode is at least SERVER' do
      input = <<-EOS
:source-highlighter: coderay
      EOS
      doc = document_from_string input, :safe => Asciidoctor::SafeMode::SERVER
      assert doc.attributes['source-highlighter'].nil?
    end
  end

end
