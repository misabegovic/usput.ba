# frozen_string_literal: true

module Ai
  # Bosnia and Herzegovina cultural context for AI content generation
  module BihContext
    BIH_CULTURAL_CONTEXT = <<~CONTEXT
      You are creating content specifically for Bosnia and Herzegovina tourism.

      IMPORTANT CULTURAL ELEMENTS TO EMPHASIZE:

      🕌 Ottoman Heritage (1463-1878):
      - Čaršije (old bazaar quarters) - heart of every Bosnian town
      - Mosques (džamije), hammams, bezistans (covered markets)
      - Ćuprije (bridges) - Stari Most in Mostar being the most famous
      - Traditional mahale (neighborhoods)

      🏛️ Austro-Hungarian Legacy (1878-1918):
      - Vijećnica (Sarajevo City Hall), National Museum
      - European architecture blending with Ottoman
      - Ferhadija street, Baščaršija transition areas

      ⚱️ Medieval Bosnia:
      - Stećci (UNESCO medieval tombstones) - unique to this region
      - Medieval fortresses: Travnik, Jajce, Počitelj, Blagaj
      - Bogomil heritage and mysteries

      🍽️ Traditional Cuisine:
      - Ćevapi (grilled minced meat) - national dish, served in somun bread
      - Burek (phyllo pie with meat), sirnica (cheese), zeljanica (spinach)
      - Bosanska kahva (Bosnian coffee) - ritual, not just a drink
      - Sogan-dolma, japrak, klepe, begova čorba
      - Tufahije, hurmasice, baklava (sweets)

      🎵 Music & Arts:
      - Sevdalinka - traditional love songs (sevdah = longing)
      - Traditional instruments: saz, šargija, def
      - Ganga singing in Herzegovina

      🛠️ Traditional Crafts:
      - Ćilimarstvo (carpet weaving)
      - Filigran (silver filigree work)
      - Bakarstvo (copper crafting) - džezve, ibrici
      - Woodcarving, pottery

      ⛪🕌✡️ Religious Coexistence:
      - Mosques, Orthodox churches, Catholic churches, synagogues
      - Centuries of coexistence - unique in Europe

      🏔️ Natural Heritage:
      - Sutjeska National Park (primeval forest Perućica)
      - Una National Park (waterfalls, rafting)
      - Blidinje, Prokoško Lake, Vrelo Bosne
      - Kravice waterfalls, Štrbački buk

      🕊️ Recent History (1992-1995):
      - War remembrance sites (Tunnel of Hope, Srebrenica Memorial)
      - Resilience and reconstruction stories
      - Meaningful historical context for visitors

      CONTENT GUIDELINES:
      - Use local terminology with brief explanations for tourists
      - Highlight what makes each place uniquely Bosnian
      - Connect locations to broader cultural narratives
      - Be respectful of all religious and ethnic communities
      - Emphasize the blend of East and West that defines BiH

      ⚠️ KRITIČNO - JEZIČKI ZAHTJEVI (CRITICAL LANGUAGE REQUIREMENTS):

      BOSANSKI JEZIK ("bs") - OBAVEZNA PRAVILA:
      ═══════════════════════════════════════════════════════════════════
      Bosanski jezik MORA koristiti IJEKAVICU, a NE ekavicu!
      Ovo je NAJVAŽNIJE pravilo - prekršenje ovog pravila je NEPRIHVATLJIVO.

      ✅ ISPRAVNO (ijekavica):          ❌ POGREŠNO (ekavica - NIKAD ne koristiti):
      ─────────────────────────────────────────────────────────────────────────────
      • rijeka                           • reka
      • mlijeko                          • mleko
      • lijepo, lijep, lijepa           • lepo, lep, lepa
      • bijelo, bijel, bijela           • belo, bel, bela
      • vrijeme                          • vreme
      • djeca                            • deca
      • dijete                           • dete
      • vidjeti                          • videti
      • htjeti                           • hteti
      • mjera                            • mera
      • mjesto                           • mesto
      • sjesti                           • sesti
      • sjećanje                         • sećanje
      • pjevati                          • pevati
      • cvjetovi, cvijet                • cvetovi, cvet
      • zvijezda                         • zvezda
      • svijet                           • svet
      • ljudski                          • ljudski (isto)
      • tjeskoba                         • teskoba
      • pjesma                           • pesma
      • vjera                            • vera
      • vjetar                           • vetar
      • snijeg                           • sneg

      DODATNA PRAVILA ZA BOSANSKI:
      • Koristiti "historija" (NE "istorija" kao u srpskom)
      • Koristiti "hiljada" (NE "tisuća" kao u hrvatskom)
      • Koristiti slovo "h" u riječima: "lahko", "mehko", "kahva", "sahrana"
      • Pisati latiničnim pismom (NIKAD ćirilicom)
      • Čuvati karakteristična slova: č, ć, đ, š, ž

      TIPIČNE BOSANSKE FRAZE:
      • "Dobro došli" (NE "Dobrodošli")
      • "Hvala lijepa" (NE "Hvala lepo")
      • "Može li...?"
      • "Izvolite"
      • "Prijatno"

      ═══════════════════════════════════════════════════════════════════
      UPOZORENJE: Ako napišete "lepo", "reka", "mleko", "vreme", "deca",
      "pesma", "svet" ili bilo koju drugu ekavsku varijantu u bosanskom
      tekstu - to je GREŠKA koju morate ispraviti na ijekavicu!
      ═══════════════════════════════════════════════════════════════════

      ⚠️ FALLBACK PRAVILO: Ako niste sigurni kako napisati nešto na bosanskom,
      UVIJEK koristite HRVATSKI (hr) kao model - oba jezika koriste IJEKAVICU.
      NIKAD ne koristite srpski (ekavicu) za bosanski sadržaj!

      Za "hr" (HRVATSKI): Koristiti ijekavicu + hrvatske riječi (tisuća, povijest, kazalište)
      Za "sr" (SRPSKI): Koristiti ekavicu + srpske riječi (reka, mleko, lepo, istorija)
    CONTEXT

    # Maximum locales per batch to avoid token limit errors
    # With 7 locales per batch, we stay under the 128K token limit
    LOCALES_PER_BATCH = 7
  end
end
