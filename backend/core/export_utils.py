import json
import io
from xhtml2pdf import pisa
from ebooklib import epub
from django.template.loader import render_to_string
from django.conf import settings

def delta_to_html(delta_str):
    """
    Extremely simple converter from Quill Delta JSON to basic HTML.
    For professional results, a more robust library would be used.
    """
    if not delta_str:
        return ""
    
    try:
        # Check if it's actually JSON
        if not (delta_str.startswith('{') or delta_str.startswith('[')):
            return delta_str.replace('\n', '<br>')

        delta = json.loads(delta_str)
        ops = delta.get('ops', [])
        html = ""
        for op in ops:
            insert = op.get('insert', '')
            attributes = op.get('attributes', {})
            
            if isinstance(insert, str):
                text = insert.replace('\n', '<br>')
                if attributes.get('bold'):
                    text = f"<strong>{text}</strong>"
                if attributes.get('italic'):
                    text = f"<em>{text}</em>"
                if attributes.get('underline'):
                    text = f"<u>{text}</u>"
                if attributes.get('header'):
                    level = attributes['header']
                    text = f"<h{level}>{text}</h{level}>"
                html += text
        return html
    except Exception as e:
        print(f"Delta conversion error: {e}")
        return delta_str.replace('\n', '<br>')

def generate_pdf(book, chapters):
    """
    Generates a PDF using xhtml2pdf.
    """
    html_content = f"""
    <html>
    <head>
        <style>
            @page {{ size: a4 portrait; margin: 2cm; }}
            body {{ font-family: 'Helvetica', 'Arial', sans-serif; line-height: 1.6; color: #333; }}
            .title-page {{ text-align: center; margin-top: 5cm; page-break-after: always; }}
            .title {{ font-size: 36pt; font-weight: bold; margin-bottom: 0.5cm; }}
            .author {{ font-size: 18pt; color: #666; }}
            .chapter {{ page-break-before: always; }}
            .chapter-title {{ font-size: 24pt; font-weight: bold; border-bottom: 2px solid #EEE; padding-bottom: 10px; margin-bottom: 20px; }}
            .content {{ font-size: 12pt; text-align: justify; }}
        </style>
    </head>
    <body>
        <div class="title-page">
            <div class="title">{book.title}</div>
            <div class="author">By {book.author.username}</div>
        </div>
    """
    
    for chapter in chapters:
        chapter_html = delta_to_html(chapter.content)
        html_content += f"""
        <div class="chapter">
            <div class="chapter-title">{chapter.title}</div>
            <div class="content">{chapter_html}</div>
        </div>
        """
    
    html_content += "</body></html>"
    
    result = io.BytesIO()
    pisa_status = pisa.CreatePDF(html_content, dest=result)
    
    if pisa_status.err:
        return None
    
    return result.getvalue()

def generate_epub(book, chapters):
    """
    Generates an EPUB using EbookLib.
    """
    epub_book = epub.EpubBook()

    # Metadata
    epub_book.set_identifier(f"srishty-book-{book.id}")
    epub_book.set_title(book.title)
    epub_book.set_language('en')
    epub_book.add_author(book.author.username)

    # Chapters
    spine = ['nav']
    toc = []
    
    for i, chapter in enumerate(chapters):
        c = epub.EpubHtml(title=chapter.title, file_name=f'chap_{i+1}.xhtml', lang='en')
        content = delta_to_html(chapter.content)
        c.content = f'<h1>{chapter.title}</h1>{content}'
        
        epub_book.add_item(c)
        spine.append(c)
        toc.append(epub.Link(f'chap_{i+1}.xhtml', chapter.title, f'chap_{i+1}'))

    # Basic setup
    epub_book.toc = tuple(toc)
    epub_book.add_item(epub.EpubNcx())
    epub_book.add_item(epub.EpubNav())

    # CSS
    style = 'BODY { font-family: serif; } H1 { text-align: center; }'
    nav_css = epub.EpubItem(uid="style_nav", file_name="style/nav.css", media_type="text/css", content=style)
    epub_book.add_item(nav_css)

    epub_book.spine = spine

    # Write to memory
    out = io.BytesIO()
    epub.write_epub(out, epub_book, {})
    return out.getvalue()
