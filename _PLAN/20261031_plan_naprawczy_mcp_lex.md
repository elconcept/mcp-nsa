# NSA / CBOSA — plan naprawy niezawodności i kompletności orzeczeń

> Audyt 2026-10-31: wyniki wywołań narzędzi bezpośrednio w kontenerach, przez portal lex oraz analiza kodu elconcept. To **plan**, nie wdrożenie. **POTWIERDZONE** = zaobserwowany objaw lub błąd w kodzie; **DO SPRAWDZENIA** = hipoteza.

## Zasady wspólne
- Interfejs użytkownika, wejściowe zapytania w języku naturalnym, wyniki, opisy, komentarze i błędy — **wyłącznie po polsku, bez selektora języka**. Identyfikatory techniczne (sygnatura, ECLI/CELEX, URL, nazwy modeli) bez zmian. Jeżeli występuje stary parametr `lang`, fazowo ukryć go w schemacie i ignorować dla zgodności, zawsze używając polskiego.
- Urzędowy tekst prawny oznaczyć źródłem i stanem; komentarz i tłumaczenie robocze to inne kategorie. Nie podszywać się pod wersje urzędowe, nie dopowiadać treści. Zachować `content` i `structuredContent` na całej ścieżce MCP.
- Każda zmiana: fixture/regresja → staging → porównanie bezpośrednio/Cloudflare/lex → rollout z migawką i rollbackiem; bez ujawniania sekretów i bez niekontrolowanych zmian produkcyjnych.

## Materiał dowodowy
- **POTWIERDZONE:** `nsa_search` i `nsa_search_by_case` zwróciły metadane dokumentu `II SA/Wa 1353/19` (ID `389F2C5B67`), a `nsa_get_judgment` przez `lex` zwracało tylko cytowania bez pełnego tekstu przy udanym wcześniejszym wywołaniu.
- **POTWIERDZONE:** późniejszy bezpośredni test `get_judgment` zakończył się `[upstream_error] ... socket hang up`; portal pokazał `{error_code:'upstream_error'}`. To drugi, odrębny problem: chwilowa awaria dostępu do CBOSA.
- **POTWIERDZONE W KODZIE:** `formatJudgment(d)` zwraca tylko pierwsze 2000 znaków z `d.text`; `buildDetailCitation(d)` obcina snippet do 200 znaków. Nie ma endpointu do bezstratnej paginacji reszty tekstu. `src/index.ts` ustawia `rejectUnauthorized: false` w HTTPS Agent — osłabia integralność pobrania orzeczenia.
- **DO SPRAWDZENIA:** czy parser `parseJudgmentHtml` gubi sentencję/uzasadnienie po zmianie HTML CBOSA; czy problem `socket hang up` zależy od blokad/rate-limit/proxy.

## Plan
1. **P0 — integralność TLS i ślad błędów:** zastąpić wyłączenie walidacji certyfikatów prawidłowym CA/pinningiem zweryfikowanego hosta; nie dopuścić do cichego pobrania podszytego dokumentu. Kategoryzować DNS/SSL/403/429/5xx/timeout/socket hang up; maksymalnie ograniczone backoff/retry i circuit breaker. Nie obchodź blokad przez agresywne scrapowanie ani nie łam warunków serwisu.
2. **P0 — pełny dokument:** `get_judgment(doc_id, offset?, limit?)` z `totalLength`, `returnedLength`, `hasMore`, `nextOffset`, `content` i `citations` albo wydzielone `get_judgment_chunk`. Nigdy nie przedstawiać 2000 znaków jako całości. Ograniczyć rozmiar każdej odpowiedzi i umożliwić rekonstrukcję bez luk.
3. **P1 — parser i fixture:** pobrać i zachować (z dozwolonego źródła) fixtures HTML różnych sądów/lat/układów, przetestować kompletność sentencji, uzasadnienia i metadanych; brak wykrywalnego tekstu = jawny `parse_error` / `content_unavailable`, nie pozorny sukces.
4. **P1 — paginacja wyszukiwania:** aktualna numeracja CBOSA od strony 1, cookies z wyszukiwania POST i brak dodatkowych rekordów spraw powiązanych. Testy `pageNumber=0`, 1, 2; poprawne narzędzie ma jawnie zwrócić informację o korekcie lub błędzie argumentu, nigdy niezdiagnozowany `upstream_error`.
5. **P2 — polski interfejs i monitoring:** komunikaty i nagłówki po polsku; metryki stabilności bez treści dokumentów; kontrola kompletności i dostępności w Portainerze oraz przez `lex`.

## Akceptacja
- Dla `389F2C5B67` poprawny odczyt sentencji i uzasadnienia (gdy źródło dostępne) składa się z chunków bez utraty znaków i ma jawny rozmiar; jednocześnie `lex` zachowuje `content`.
- Certyfikat serwera jest weryfikowany, a transient `socket hang up` ma jednoznaczną, ograniczoną politykę retry; żadna awaria nie staje się pustym wynikiem.
- 3+ fixture HTML przechodzą test struktury i zgodności z oryginałem.

## Pliki / dowody
`src/index.ts` (HTTPS agent, `parseJudgmentHtml`, `formatJudgment`, `get_judgment`), `test/fixtures/`, `test/parse.mjs`, kontener `mcp-nsa`.
