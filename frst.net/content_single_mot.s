; Contentdata for JonSharp.netCyberterminal
 * Converted from content_single.md
 

	section rodata,data


	xdef	combined_content
	xdef	combined_content_end
	xdef	content_length

	align	4
combined_content:
        dc.b " Welcome to my web mirror!  This is a PCD-68[1] ROM sampler of my primary\n"
        dc.b " digital space over atgopher://jonsharp.net-- justa flavor for people who\n"
        dc.b " haven'tyetdiscovered the joy of port70.  If you're wondering whatthe\n"
        dc.b " heck Gopher is,well... it's like the web, butten ports prior.\n\n"
        dc.b " [1] PCD-68 is a virtual retrocomputer of my design.  You are reading this\n"
        dc.b " textinside a version of my pcd68 emulator compiled for the web.\n\n"
    
        dc.b " ## Who Am I?\n\n"
        dc.b " I'm Jon Sharp,a software developer,vintage computer collector,and\n"
        dc.b " retrocomputing enthusiastwith a serious case of nostalgia for when computers\n"
        dc.b " were actually personal.\n\n"
        dc.b " When I'm nothomebrewing computers,hacking 68k assembly or evangelizing\n"
        dc.b " Plan 9,you mightfind me hiking or risking more ER visits on my surf-skate.\n\n"
    
        dc.b " ## The Retrocomputing Laboratory\n\n"
        dc.b " My digital archaeology spans everything from Apple 1 replicas to Palm Pilots,\n"
        dc.b " Newtons and handheld game consoles.  Some highlights from the collection:\n\n"
        dc.b " Bare-metal Macintosh Programming - Whathappens when you throw outthe Mac\n"
        dc.b " ROM and its Toolbox?  You geta blank slate for imagination (and a lotof 68k\n"
        dc.b " assembly headaches).  I've been progressively building an alternative\n"
        dc.b " environmentfor the Mac Plus,because why not?\n\n"
        dc.b " Gameboy EthernetProject- Back in university,I turned a Game Boy Color into\n"
        dc.b " a remote reporting tool with the help of a unique embedded system.\n\n"
        dc.b " Painted Laptops - Sometimes a computer needs more than justfresh thermal\n"
        dc.b " paste.  I've given vintage laptops the full makeover treatment: camo patterns\n"
        dc.b " for 486 machines thatneed to blend with the forest,\"Pentium Inside/Outside\"\n"
        dc.b " body art,and hot-rod red TiBooks.\n\n"
    
        dc.b " ## FRST Computer:  The \"Spatula City\" of Cyberdecks\n\n"
        dc.b " My primary art projectis FRST Computer - a small batch,artisan personal\n"
        dc.b " computer company where I craftunique machines one batch ata time.\n\n"
        dc.b "  << A gopher-firstpersonal computer company! -- gopher://frstcomputer.com >>\n\n"
        dc.b " Model Three:  If you're going to build a time machine...\n\n"
        dc.b " Models One & Two:  ePaper CyberTerminals - an exploration in \"justenough\"\n"
        dc.b " microcontroller-based personal computing\n\n"
        dc.b " FRST represents my exploration of minimalist,sustainable	computing -\n"
        dc.b " empowering users to adopta simpler digital lifestyle and replace ad-driven\n"
        dc.b " feeds with real-world community building.  It's also an homage to the most\n"
        dc.b " brilliantartist-engineers of the personal computing era.\n\n"
    
        dc.b " ## Other matters of Artand Philosophy\n\n"
        dc.b " My 4\" watercolor books representone of my primary artistic outlets - tiny\n"
        dc.b " paintings created during moments I mightotherwise be tempted to scroll on a\n"
        dc.b " smartphone.  And justto demonstrate thatPCD-68 can do \"fancy\" graphics,\n"
        dc.b " I've included two of my watercolors (in all their 1-bitglory!) in this ROM.\n"
        dc.b " The 'a' key activates \"art mode\",allowing you to navigate ('j'/'k') between\n"
        dc.b " the two stored images.  Use the 't' key to return to \"text mode\".\n\n"
        dc.b " I also believe deeply thatuptime is overrated,entropy is good (and so is\n"
        dc.b " Lisp) and thatsoftware complexity will kill us all.\n\n"
    
        dc.b " ## Gopherspace:  Welcome to Radiator Springs!\n\n"
        dc.b " Why Gopher in 2025?  Because sometimes the best way forward is to step back\n"
        dc.b " and remember whatmade computing personal in the first place.  Gopher is\n"
        dc.b " like the web, but with soul - a place where content matters more than\n"
        dc.b " presentation,where community trumps commerce,and where you can actually\n"
        dc.b " read something withoutseventeen data brokers siphoning your data.\n\n"
        dc.b " My gopher hole has been running for a few years now,serving up everything\n"
        dc.b " from technical deep-dives to hard-to-find retrocomputing utilities,drivers\n"
        dc.b " and apps to album reviews (M83's \"Hurry Up,We're Dreaming\" won my 2011\n"
        dc.b " Album of the Year award,in case you were wondering).  It's a labor of love,\n"
        dc.b " a digital garden,and proof thatgood things come to those who\n"
        dc.b " embrace plain text.\n\n"
    
        dc.b " ## Gopher stickers\n\n"
        dc.b " If you send $2 to my PO Box,I'll send you a \"Gopher: Good. Enough.\" sticker\n"
        dc.b " for thatfancy MacBook of yours! ;)\n\n"
    
        dc.b " --\n"
        dc.b " Full Gopher Experience: gopher://jonsharp.net\n"
        dc.b " Email: jon@jonsharp.net\n"
        dc.b " Mastodon: @jrsharp@mastodon.sdf.org\n"
        dc.b " GitHub: @jrsharp\n"
        dc.b " --\n\n"
    
        dc.b " EOL\n"
        dc.b ""

combined_content_end:


content_length:
        dc.l combined_content_end - combined_content


section_positions:
        dc.w 0      
        dc.w 8      
        dc.w 15     
        dc.w 29     
        dc.w 43     
        dc.w 53      
        dc.w 67     
        dc.w 71      
        dc.w 78      
        dc.w 78     
