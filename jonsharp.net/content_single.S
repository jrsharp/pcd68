/* Content data for JonSharp.net Cyberterminal
 * Converted from content_single.md
 */

.section .rodata, "a"

/* Export the combined content symbol */
.global combined_content
.global combined_content_end
.global content_length

.align 4
combined_content:
    .ascii "Welcome to my web mirror!  This is a PCD-68[1] ROM sampler of my primary\n"
    .ascii "digital space over at gopher://jonsharp.net -- just a flavor for people\n"
    .ascii "who haven't yet discovered the joy of port 70.  If you're wondering what\n"
    .ascii "the heck Gopher is, well... it's like the web, but a little more spartan.\n\n"
    .ascii "[1] PCD-68 is a virtual retrocomputer of my design.  You are reading this\n"
    .ascii "text inside a version of my pcd68 emulator compiled for the web.\n\n"
    
    .ascii "## Who Am I?\n\n"
    .ascii "I'm Jon Sharp, a software developer, vintage computer collector, and\n"
    .ascii "retrocomputing enthusiast with a serious case of nostalgia for when\n"
    .ascii "computers were actually personal.\n\n"
    .ascii "When I'm not homebrewing computers, hacking 68k assembly or evangelizing\n"
    .ascii "Plan 9, you might find me hiking or risking more ER visits on my\n"
    .ascii "surf-skate.\n\n"
    
    .ascii "## The Retrocomputing Laboratory\n\n"
    .ascii "My digital archaeology spans everything from Apple 1 replicas to handheld\n"
    .ascii "game consoles.  Some highlights from the collection:\n\n"
    .ascii "Bare-metal Macintosh Programming - What happens when you throw out the Mac\n"
    .ascii "ROM and its Toolbox?  You get a blank slate for imagination (and a lot of\n"
    .ascii "68k assembly headaches).  I've been progressively building an alternative\n"
    .ascii "OS for the Mac Plus, because why not?\n\n"
    .ascii "Gameboy Ethernet Project - Back in university, I turned a Game Boy Color\n"
    .ascii "into a remote reporting tool via Ethernet with the help of a unique\n"
    .ascii "embedded system.\n\n"
    .ascii "Painted Laptops - Sometimes a computer needs more than just fresh thermal\n"
    .ascii "paste. I've given vintage laptops the full makeover treatment: camo\n"
    .ascii "patterns for 486 machines that need to blend with the forest, \"Pentium\n"
    .ascii "Inside/Outside\" body art, and hot-rod red TiBooks.\n\n"
    
    .ascii "## FRST Computer: When Art Meets Computing\n\n"
    .ascii "My primary art project is FRST Computer - a small batch, artisan personal\n"
    .ascii "computer company where I craft beautiful and unique machines one batch at\n"
    .ascii "a time.  Think of it as the intersection of industrial design, elegant\n"
    .ascii "source code, and a healthy skepticism of algorithmic social networking.\n\n"
    .ascii "Model Three:  If you're going to build a time machine...\n\n"
    .ascii "Models One & Two:  ePaper CyberTerminals - For when you want efficiency,\n"
    .ascii "readability, and the ability to compute without burning through your\n"
    .ascii "battery in two hours.\n\n"
    .ascii "FRST represents my exploration of minimalist, sustainable computing -\n"
    .ascii "empowering users to adopt a simpler digital lifestyle and replace ad-driven\n"
    .ascii "feeds with real-world community building.  It's an homage to the most\n"
    .ascii "brilliant artist-engineers of the personal computing era.\n\n"
    
    .ascii "## Art & Philosophy\n\n"
    .ascii "Someone once said that to be an artist, one needs to be unafraid to make\n"
    .ascii "bad art. My 4\" watercolor books represent one of my primary artistic\n"
    .ascii "outlets - tiny paintings created during moments I might otherwise be\n"
    .ascii "tempted to scroll on a smartphone. Judge for yourself how unafraid I am\n"
    .ascii "to make art!\n\n"
    .ascii "I also believe deeply that uptime is overrated, entropy is good (and so\n"
    .ascii "is Lisp) and that software complexity will kill us all.\n\n"
    
    .ascii "## The Gopher Philosophy\n\n"
    .ascii "Why Gopher in 2025?  Because sometimes the best way forward is to step\n"
    .ascii "back and remember what made computing personal in the first place.  Gopher\n"
    .ascii "is like the web, but with soul - a place where content matters more than\n"
    .ascii "presentation, where community trumps commerce, and where you can actually\n"
    .ascii "read something without seventeen data brokers siphoning your data.\n\n"
    .ascii "My gopher hole has been running for a few years now, serving up everything\n"
    .ascii "from technical deep-dives to album reviews (M83's \"Hurry Up, We're\n"
    .ascii "Dreaming\" won my 2011 Album of the Year award, in case you were\n"
    .ascii "wondering). It's a labor of love, a digital garden, and proof that good\n"
    .ascii "things come to those who embrace plain text.\n\n"
    
    .ascii "--\n"
    .ascii "Full Gopher Experience: gopher://jonsharp.net\n"
    .ascii "Email: jon@jonsharp.net\n"
    .ascii "Mastodon: @jrsharp@mastodon.sdf.org\n"
    .ascii "GitHub: @jrsharp\n"
    .ascii "--\n\n"
    .ascii "Or just enjoy this PCD-68 ROM sampler and marvel at the fact that someone\n"
    .ascii "built a custom emulator just to show off their gopher content.\n\n"
    
    .ascii "--- END OF CONTENT ---\n\n"
    .asciz ""

combined_content_end:

/* Calculate content length at assembly time */
content_length:
    .long combined_content_end - combined_content 

/* Section jump positions (line numbers) */
section_positions:
    .word 0      /* Section 0: Top */
    .word 9      /* Section 1: Who am I */
    .word 18     /* Section 2: Retrocomputing */
    .word 36     /* Section 3: FRST */
    .word 54     /* Section 4: Art and Philosophy */
    .word 64     /* Section 5: Gopher */ 
    .word 78     /* Section 6: Footer */ 
    .word 85     /* Section 7: footnote */ 
    .word 85     /* Section 8: footnote */ 
    .word 85     /* Section 9: footnote */ 
