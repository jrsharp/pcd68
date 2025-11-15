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
    .ascii " Welcome to my web mirror!  This is a PCD-68[1] ROM sampler of my primary\n"
    .ascii " digital space over at gopher://jonsharp.net -- just a flavor for people who\n"
    .ascii " haven't yet discovered the joy of port 70.  If you're wondering what the\n"
    .ascii " heck Gopher is, well... it's like the web, but ten ports prior.\n\n"
    .ascii " [1] PCD-68 is a virtual retrocomputer of my design.  You are reading this\n"
    .ascii " text inside a version of my pcd68 emulator compiled for the web.\n\n"
    
    .ascii " ## Who Am I?\n\n"
    .ascii " I'm Jon Sharp, a software developer, vintage computer collector, and\n"
    .ascii " retrocomputing enthusiast with a serious case of nostalgia for when computers\n"
    .ascii " were actually personal.\n\n"
    .ascii " When I'm not homebrewing computers, hacking 68k assembly or evangelizing\n"
    .ascii " Plan 9, you might find me hiking or risking more ER visits on my surf-skate.\n\n"
    
    .ascii " ## The Retrocomputing Laboratory\n\n"
    .ascii " My digital archaeology spans everything from Apple 1 replicas to Palm Pilots,\n"
    .ascii " Newtons and handheld game consoles.  Some highlights from the collection:\n\n"
    .ascii " Bare-metal Macintosh Programming - What happens when you throw out the Mac\n"
    .ascii " ROM and its Toolbox?  You get a blank slate for imagination (and a lot of 68k\n"
    .ascii " assembly headaches).  I've been progressively building an alternative\n"
    .ascii " environment for the Mac Plus, because why not?\n\n"
    .ascii " Gameboy Ethernet Project - Back in university, I turned a Game Boy Color into\n"
    .ascii " a remote reporting tool with the help of a unique embedded system.\n\n"
    .ascii " Painted Laptops - Sometimes a computer needs more than just fresh thermal\n"
    .ascii " paste.  I've given vintage laptops the full makeover treatment: camo patterns\n"
    .ascii " for 486 machines that need to blend with the forest, \"Pentium Inside/Outside\"\n"
    .ascii " body art, and hot-rod red TiBooks.\n\n"
    
    .ascii " ## FRST Computer:  The \"Spatula City\" of Cyberdecks\n\n"
    .ascii " My primary art project is FRST Computer - a small batch, artisan personal\n"
    .ascii " computer company where I craft unique machines one batch at a time.\n\n"
    .ascii "  << A gopher-first personal computer company! -- gopher://frstcomputer.com >>\n\n"
    .ascii " Model Three:  If you're going to build a time machine...\n\n"
    .ascii " Models One & Two:  ePaper CyberTerminals - an exploration in \"just enough\"\n"
    .ascii " microcontroller-based personal computing\n\n"
    .ascii " FRST represents my exploration of minimalist, sustainable computing -\n"
    .ascii " empowering users to adopt a simpler digital lifestyle and replace ad-driven\n"
    .ascii " feeds with real-world community building.  It's also an homage to the most\n"
    .ascii " brilliant artist-engineers of the personal computing era.\n\n"
    
    .ascii " ## Other matters of Art and Philosophy\n\n"
    .ascii " My 4\" watercolor books represent one of my primary artistic outlets - tiny\n"
    .ascii " paintings created during moments I might otherwise be tempted to scroll on a\n"
    .ascii " smartphone.  And just to demonstrate that PCD-68 can do \"fancy\" graphics,\n"
    .ascii " I've included two of my watercolors (in all their 1-bit glory!) in this ROM.\n"
    .ascii " The 'a' key activates 'art mode', allowing you to navigate ('j'/'k') between\n"
    .ascii " the two stored images.  Use the 't' key to return to 'text mode'.\n\n"
    .ascii " I also believe deeply that uptime is overrated, entropy is good (and so is\n"
    .ascii " Lisp) and that software complexity will kill us all.\n\n"
    
    .ascii " ## Gopherspace:  Welcome to Radiator Springs!\n\n"
    .ascii " Why Gopher in 2025?  Because sometimes the best way forward is to step back\n"
    .ascii " and remember what made computing personal in the first place.  Gopher is\n"
    .ascii " like the web, but with soul - a place where content matters more than\n"
    .ascii " presentation, where community trumps commerce, and where you can actually\n"
    .ascii " read something without seventeen data brokers siphoning your data.\n\n"
    .ascii " My gopher hole has been running for a few years now, serving up everything\n"
    .ascii " from technical deep-dives to hard-to-find retrocomputing utilities, drivers\n"
    .ascii " and apps to album reviews (M83's \"Hurry Up, We're Dreaming\" won my 2011\n"
    .ascii " Album of the Year award, in case you were wondering).  It's a labor of love,\n"
    .ascii " a digital garden, and proof that good things come to those who\n"
    .ascii " embrace plain text.\n\n"
    
    .ascii " ## Gopher stickers\n\n"
    .ascii " If you send $2 to my PO Box, I'll send you a 'Gopher: Good. Enough.' sticker\n"
    .ascii " for that fancy MacBook of yours! ;)\n\n"
    
    .ascii " --\n"
    .ascii " Full Gopher Experience: gopher://jonsharp.net\n"
    .ascii " Email: jon@jonsharp.net\n"
    .ascii " Mastodon: @jrsharp@mastodon.sdf.org\n"
    .ascii " GitHub: @jrsharp\n"
    .ascii " --\n\n"
    
    .ascii " ## One more thing...\n\n"

    .ascii " I've added a 'UART' mode to this ROM.  For the wasm deployment of my pcd68\n"
    .ascii " emulator, this will open a websocket connection to my 'Aether' mesh protocol\n"
    .ascii " simulation / gateway.  This service presents an AT command-style interface,\n"
    .ascii " emulating a custom LoRa radio modem.  If this is working correctly, it will\n"
    .ascii " plop you down in the middle of a simulated mesh network with other\n"
    .ascii " interactive clients, allowing you to chat with other users:\n\n"

    .ascii " > AT+HELP -> AT+INIT -> AT+NETALIAS=username -> AT+NETJOIN -> AT+SEND=hi!\n\n"

    .ascii " EOL\n"
    .asciz ""

combined_content_end:

/* Calculate content length at assembly time */
content_length:
    .long combined_content_end - combined_content 

/* Section jump positions (line numbers) */
section_positions:
    .word 0      /* Section 0: Top */
    .word 8      /* Section 1: Who am I */
    .word 15     /* Section 2: Retrocomputing */
    .word 29     /* Section 3: FRST */
    .word 43     /* Section 4: Art and Philosophy */
    .word 53     /* Section 5: Gopherspace */ 
    .word 67     /* Section 6: Gopher stickers */
    .word 71     /* Section 7: Footer */ 
    .word 78     /* Section 8: End */ 
    .word 78     /* Section 9: End */
