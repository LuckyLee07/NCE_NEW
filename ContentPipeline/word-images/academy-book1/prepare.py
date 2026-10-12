#!/usr/bin/env python3
"""Prepare reviewed word senses and repeatable four-cell ImageGen jobs."""
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PILOT = ROOT / 'Design/2026-10-11-word-illustration-pilot'

# These are live UI text, never baked into the illustration. The target is blank.
HINTS = {
 'me':'Please help ___.', 'is':'She ___ a student.', 'this':'___ is my bag.\n↓',
 'your':'Is this ___ bag?', 'it':'___ is a book.', 'very much':'Thank you ___ ___.',
 'my':'I have a bag.\nThis is ___ bag.', 'too':'I like tea.\nI like tea, ___.',
 'I':'___ am a student.', 'am':'I ___ a student.', 'are':'We ___ students.',
 'what':'___ is your name?', 'how':'___ are you?', 'whose':'___ bag is this?',
 'perhaps':'___ it will rain.\n☀  /  ☂', 'same':'○ ○\n＝', 'matter':'What is the ___?',
 'which':'___ one do you want?\n●   ○   ○', 'of':'a cup ___ tea',
 'must':'You ___ stop at a red light.', 'who':'___ is that man?',
 'with':'Come ___ me.', 'another':'This cup is broken.\nMay I have ___ one?',
 'of course':'Can I help?\n___ ___!', 'now':'PAST  ·  ●  ·  FUTURE',
 'can':'I ___ swim.', 'minute':'60 s', 'either':"I don't like tea.\nI don't, ___.",
 'sometimes':'● ○ ○ ● ○ ○ ●', 'always':'● ● ● ● ● ● ●',
 'usually':'● ● ● ○ ● ● ●', 'o\'clock':'3:00', 'moment':'…  ●  …',
 'yet':"It is not ready ___.", 'remain':'Please ___ seated.',
 'yourself':'Do it ___.', 'ourselves':'We did it ___.', 'keep':'Eat well and ___ fit.',
 'spend':'We ___ the weekend at home.', 'just':'It is ___ right.',
 'time':'× 1     × 2     × 3', 'again':'① → ② → ①', 'week':'7 × 24 h',
 'phrase':'a cup of tea', 'ago':'←  2 years  ·  NOW', 'till':'09:00 ━━━━━ 17:00',
 'nearly':'● ● ● ● ● ● ● ● ● ○', 'already':'It is ___ finished.',
 'never':'○ ○ ○ ○ ○ ○ ○', 'ever':'Have you ___ been here?',
 'believe':'I ___ you.', 'may':'___ I come in?', 'how long':'START ━━━━━ END\n↔  ?',
 'since':'2020 ━━━━━ NOW', 'why':'___ are you late?',
 'because':'I stayed inside ___ it rained.', 'worth':'This book is ___ £5.',
 'still':'I am ___ waiting.', 'plenty':'● ● ● ● ●\n● ● ● ● ●\n● ● ● ● ●',
 'describe':'Can you ___ the bag?', 'address':'12 King Street',
 'belong':'This bag is mine.\nIt ___s to me.', 'ow':'___! That hurts!',
 'at once':'NOW  →', 'sure':'Are you ___?', 'association':'○ ─ ○ ─ ○\n╲  │  ╱\n○',
 'soon':'NOW  ···→  ●', 'enough':'4 people\n● ● ● ●', 'rest':'● ● │ ○ ○ ○',
 'as well':'She is coming ___ ___.', 'a little':'▰ ▱ ▱ ▱ ▱',
 'less':'● ● ● ● → ● ●', 'a few':'● ● ●',
 'instead':'○  →  ●', 'none':'∅', 'neither':"I don't like it.\n___ do I.",
 'except':'● ● ● ○ ● ●', 'anyone':'Can ___ help?',
 'everything':'● ● ● ●\n✓ ✓ ✓ ✓', 'anything':'Do you need ___?',
 'nothing':'There is ___ here.\n∅', 'later':'NOW ─────────→ ●',
 'happen':'What will ___ next?', 'during':'START ├── ● ──┤ END',
 'terribly':'very, very…', 'mean':'What does this word ___?',
 'at least':'≥', 'mile':'1 mi ≈ 1.609 km',
 'darling':'Good morning, ___.', 'latest':'2024 → 2025 → ●',
 'depend':'It ___s on the weather.', 'hundred':'100', 'five':'● ● ● ● ●',
 'one':'●', 'number':'1  2  3', 'year':'12 × 1 month',
}
for i, word in enumerate('January February March April May June July August September October November December'.split(),1):
    HINTS[word]=f'{i:02d} / 12\n'+' '.join('●' if j==i else '○' for j in range(1,13))
for i, word in enumerate('Monday Tuesday Wednesday Thursday Friday Saturday Sunday'.split(),1):
    HINTS[word]=f'{i:02d} / 07\n'+' '.join('●' if j==i else '○' for j in range(1,8))
HINTS['weekend']='○ ○ ○ ○ ○ ● ●'

# Explicit semantic equivalents only; never infer sharing from case-folding.
ALIASES = {
 'hi':'hello', 'thanks':'thank you', 'Mr.':'sir', 'fine':'well',
 'phone':'telephone', 'hard':'hard-working', 'in front of':'front',
 'person':'man', 'guy':'man', 'people':'crowd', 'pence':'penny',
 'enter':'into', 'place':'put', 'travel':'trip', 'pretty':'beautiful',
 'pleasantly':'smile',
}
# Different senses needing stronger direction than the English spelling alone.
SCENES = {
 'get up':'an adult getting OUT OF BED in the morning, sitting at bed edge and placing feet into slippers, fully clothed in pajamas; not merely standing from a chair',
 'madam':'a respectfully presented adult woman in simple smart everyday clothes, neutral portrait, no wedding status cues',
 'extra':'three identical pale grey cups in a row plus ONE additional blue cup offset to the right, extra/additional item emphasized',
 'excuse':'a person gently raising an open hand to get another adult\'s attention politely, friendly interaction',
 'pardon':'a listener cupping one ear and leaning slightly toward a speaker, polite request to repeat, no text',
 'thank you':'a grateful adult placing hand over chest and smiling at a person offering a small gift, polite gratitude',
 'please':'a person politely requesting an offered cup with open palms, friendly and non-commanding',
 'sorry':'an apologetic person with lowered head and open palms next to an accidentally knocked-over empty cup, no injury',
 'here':'a large blue downward arrow points to a clearly marked blue spot directly beneath it, location here',
 'sir':'a respectfully presented adult gentleman in simple jacket, no crown or military decorations',
 'Miss':'a young adult woman in everyday clothes, respectful portrait, no wedding symbolism',
 'Mrs.':'an adult woman wearing a simple wedding band on visible hand, respectful everyday portrait',
 'good':'an intact fresh red apple with a small blue check mark, good condition',
 'new':'a pristine new pair of white shoes next to their open shoe box, no text',
 'French':'a small adult traveler beside a simplified Eiffel Tower, nationality mnemonic only; no stereotyped facial features',
 'German':'a small adult beside a recognizable Brandenburg Gate, nationality mnemonic; no stereotyped facial features',
 'Japanese':'an adult beside a red torii gate with simple Mount Fuji silhouette, nationality mnemonic; no stereotyped facial features',
 'Korean':'an adult beside a traditional Korean palace gateway, nationality mnemonic; no stereotyped facial features',
 'Chinese':'an adult beside a small segment of the Great Wall, nationality mnemonic; no stereotyped facial features',
 'Danish':'an adult beside a simplified Copenhagen Nyhavn harbor house, nationality mnemonic only',
 'Norwegian':'an adult beside a compact steep fjord and wooden waterside house, nationality mnemonic only',
 'name':'a simple personal identity badge with an adult portrait and three blank horizontal lines; no words',
 'nationality':'a passport with small globe emblem beside three different country-shaped map silhouettes, no labels',
 'job':'a worker holding a briefcase beside a small office desk, paid employment',
 'operator':'an adult keyboard/computer operator seated at a desk typing on desktop keyboard, not heavy machinery',
 'well':'an adult looking energetic and healthy with relaxed posture and a small blue check mark, health sense',
 'fine':'a pleasant bright sunny scene with a small blooming plant, beautiful/fine sense',
 'blue':'a single blue watercolor paint swatch with a small brush; preserve saturated blue exactly',
 'white':'a white porcelain cup on a VERY pale grey oval wash so whiteness is visible; no blue body',
 'green':'a single green watercolor paint swatch and brush; actual green',
 'brown':'a single brown watercolor paint swatch and brush; actual brown',
 'pink':'a single pink watercolor paint swatch and brush; actual pink',
 'colour':'three separate watercolor paint swatches red, yellow and blue beside a small brush',
 'customs':'an airport customs officer checking an open suitcase on a counter, no police chase or text',
 'officer':'an adult official at a customs desk with a plain badge, no weapons or military context',
 'sales reps':'two adult sales representatives showing a sample product from a case to a customer',
 'right':'a dark blue arrow pointing horizontally RIGHT, spatial sense; avoid a check mark',
 'electric':'a simple plug with two prongs and connected cord beside small lightning bolt, no wiring instructions',
 'left':'one dark blue horizontal arrow pointing LEFT',
 'middle':'five small cubes in a row, ONLY the central third cube colored blue, others pale grey',
 'air':'a person opening a window with gentle air-flow arrows moving through it, action ventilate a room, not generic atmosphere',
 'dust':'a person using a feather duster to remove small dust specks from a shelf, verb dust',
 'after':'two people walking rightwards, the REAR person highlighted blue and front person pale grey, following behind',
 'over':'one blue ball with a curved arrow passing ABOVE a low grey block from one side to the other',
 'along':'simple vertical river and bank with a blue arrow running PARALLEL along the bank, not across water',
 'bank':'a narrow river bend with its near grassy BANK highlighted, no financial bank',
 'into':'a blue ball with an arrow going INTO an open grey box, entry direction clear',
 'make':'two otherwise similar cars with DIFFERENT simple geometric badges on their grilles, product make/brand sense; no real logos',
 'paint':'a hand holding a paintbrush applying a pale-blue coat to a wooden chair, verb painting a surface',
 'front':'one blue ball IN FRONT OF a grey box, visibly in foreground overlapping its lower edge',
 'drop':'a cup slipping down from an open hand with a simple downward movement cue, no shattered glass',
 'tobacco':'a small bundle of cured brown tobacco leaves with a tiny heap of cut dried strands, no smoking person or branding',
 'boil':'a small open pot of water with clearly visible rising bubbles and modest steam on a hob',
 'handwriting':'a hand holding a pen making simple illegible flowing ink strokes on paper, no readable letters',
 'like':'a smiling person happily choosing a small cup of tea with a simple heart cue',
 'want':'a person reaching toward a desirable cup on a nearby shelf, wanting rather than owning',
 'lamb':'a clean uncooked lamb chop on a white plate with subtle rosemary, FOOD not live lamb',
 'chicken':'one live domestic hen, no roasted chicken; noun bird in source vocabulary',
 'truth':'a person admitting a broken cup with an honest open-hand gesture, no mask or deception glamor',
 'Greece':'a compact accurate recognizable Parthenon temple on a hill, geographic mnemonic, no modern skyline',
 'country':'a peaceful rural house and field, countryside sense rather than arbitrary political map',
 'climate':'a small landscape enclosed by a circular sequence of sun, rain cloud and snowflake, long-term seasonal patterns',
 'weather':'a single sky vignette combining a sun and small rain cloud, weather conditions',
 'spring':'a budding leafy branch with a few small blossoms, spring season not metal coil',
 'mild':'a person comfortably wearing a light cardigan outdoors under gentle sunshine, not hot or snowy',
 'north':'a minimal four-direction compass with ONLY the upward arrow blue and other three grey, no letters',
 'east':'a minimal four-direction compass with ONLY the rightward arrow blue and other three grey, no letters',
 'south':'a minimal compass with ONLY downward arrow blue and other three grey, no letters',
 'west':'a minimal compass with ONLY leftward arrow blue and other three grey, no letters',
 'rise':'sun just above horizon with a short UPWARD arrow, sunrise',
 'set':'sun touching horizon with a short DOWNWARD arrow, sunset, not a set of objects',
 'subject':'two people discussing with a speech bubble containing a small tree picture, topic of conversation not school subject',
 'stay':'traveler remaining seated inside a small house, suitcase placed beside them, no departure arrows',
 'call':'a person requesting a doctor through a telephone, summoning help rather than yelling',
 'cold':'a fully clothed person shivering with arms folded and visible scarf, cold temperature adjective not common cold',
 'aspirin':'two plain round tablets next to a plain blister strip, medicinal concept only, no brand or dosage',
 'measles':'a calm child with a sparse red dotted rash on cheeks and arms, simple non-diagnostic illustration, non-graphic',
 'mumps':'a person with gently indicated swelling near both jaw angles, simple non-graphic symptom mnemonic',
 'rich':'a buttery creamy slice of cake with cream, rich/oily FOOD sense; no wealthy person',
 'absent':'a row of three classroom desks; two occupied, central seat conspicuously empty',
 'finish':'the finish line of a running track with a runner just crossing, noun end/finish',
 'answer':'a person picking up a telephone receiver and putting it to their ear, answer a phone not exam answer',
 'last':'four people waiting in a line facing right, the LAST/rearmost person on left highlighted blue',
 'phrasebook':'a small pocket travel book with two speech-bubble symbols on cover, no writing',
 'pair':'two matching shoes side by side, unmistakable pair',
 'bath':'a white bathtub with water, towel and modest bubbles, no exposed person',
 'roast':'a golden-brown roast joint of meat in a roasting tray, adjective cooked in oven',
 'film':'a short curl of motion-picture film strip with blank frames, not plastic wrapping',
 'crash':'two toy-like cars with bent bumpers after a low-speed collision, no people or injury, restrained non-graphic',
 'cost':'a small product beside a few plain coins and price-tag shape, no text',
 'pound':'a single British pound coin with clearly drawn £ symbol only, no portrait and no numbers',
 'penny':'a single small copper British penny coin with numeral 1 only, no portrait',
 'miss':'an adult looking wistfully at a framed portrait of a friend, missing someone not failing a target',
 'poor':'a person in simple worn clothing beside a nearly empty wallet, dignified depiction without caricature',
 'return':'a person with suitcase coming BACK toward a house, a curved returning arrow clarifies',
 'Madrid':'a small recognizable Puerta de Alcala gate, Madrid location mnemonic',
 'Tokyo':'a small Tokyo Tower with low simplified urban silhouette, no labels',
 'New York':'a simplified Statue of Liberty with tiny skyline, recognizable location mnemonic',
 'London':'a simplified Elizabeth Tower clock and small red double-decker bus',
 'zip':'a close-up of a partly opened zipper with clear metal pull and teeth',
 'handle':'a close-up of a hand gripping the curved HANDLE of a suitcase, handle emphasized blue',
 'back':'a fully clothed adult viewed from BEHIND with upper back gently highlighted blue, body-part sense',
 'X-ray':'a single simple hand radiograph shown on a small light panel, no fracture diagnosis',
 'card':'one picture POSTCARD front and back with stamp rectangle and dividing line, no writing, not playing card',
 'paper':'an EXAM answer sheet with blank lines and checkboxes next to a pencil, not generic stack of paper',
 'mark':'an exam sheet with several check marks and one clearly readable 8/10 score, no other text',
 'spell':'three wooden letter tiles C A T aligned in sequence, exact three letters only',
 'present':'one wrapped gift box with pale-blue ribbon, noun gift not time-present',
 'suit':'an adult trying a jacket that fits neatly and comfortably, verb be suitable, not just formal suit',
 'teaspoonful':'one small teaspoon filled level with white sugar above a cup, one full teaspoon',
 'model':'two versions of a small radio side by side with slightly different knob layouts, product model sense not fashion model',
 'deposit':'a small initial group of blue coins moved toward a reserved product while remaining coins stay grey, down payment mnemonic',
 'instalment':'three evenly spaced small piles of coins along a timeline toward a purchased item, payment in instalments',
 'conductor':'a BUS ticket conductor holding a ticket roll and small ticket machine beside a bus doorway, not orchestra conductor',
 'fare':'a passenger handing coins to a bus driver with small bus silhouette, transport fare',
 'note':'one plain British banknote with £ sign only, paper money sense, no musical note',
 'tramp':'a dignified adult traveler in worn coat carrying a small bundle, no mocking caricature',
 'swallow':'a person in profile swallowing a small sip of water with a subtle downward throat arrow, verb not bird',
 'thief':'a stealthy person reaching for an unattended bag, non-violent scene, no weapon',
 'voice':'a close-up side profile of a mouth speaking with three simple sound waves, spoken voice not singing stage',
 'grow':'three stages of a plant increasing from seedling to young leafy plant, growing',
 'nuisance':'a person bothered by a small fly buzzing near their ear, nuisance concept',
 'famous':'a performer acknowledged by a small crowd with a few camera flashes, fame without real celebrity likeness',
 'speed':'a simple roadside circular speed-limit sign with the numeral 30 ONLY beside a small car, source meaning speed limit',
 'charge':'a traffic officer handing a fine notice to a driver, fine/penalty sense, no battery or charging cable',
 'pool':'a football predictions coupon with blank grid and a small stack of coins, betting stake/football pools sense; NO swimming pool',
 'line':'a simple railway LINE with two rails converging gently into distance and sleepers, not fishing line',
 'powder':'a small open cosmetic face powder container with powder puff, pale peach powder',
 'compact':'a small open hinged cosmetic compact showing mirror in lid and powder pan below',
 'ugly':'an unattractive dented rusty object beside a neat counterpart, do not label a person ugly',
 'wood':'a small group of several trees forming woodland, plural collective woods not a plank',
 'litter basket':'a small open public waste bin with a piece of paper inside, not laundry basket',
 'rusty':'a small old iron key with visible warm brown-orange rust patches, clearly rust not wood',
 'prosecute':'a courthouse facade and a legal case folder with simple scales-of-justice symbol, legal proceedings mnemonic, no prison stereotype',
}

def main():
    with sqlite3.connect((ROOT/'NCE_ALL/data/NCE.db').resolve().as_uri()+'?mode=ro',uri=True) as db:
        rows=db.execute('SELECT word_name, word_translation, lesson_id FROM words WHERE book_id=1 ORDER BY lesson_id, order_id').fetchall()
    unique={}
    for word,meaning,lesson in rows:
        unique.setdefault(word,{'word':word,'meaning':meaning,'lessons':[]})['lessons'].append(lesson)
    assert len(unique)==605
    pilot=json.loads((PILOT/'report.json').read_text())
    pilot_by={x['word']:x for x in pilot['tiles']}
    entries=[]
    for word,row in unique.items():
        row['filename']='academy-b1-'+hashlib.sha256(word.encode()).hexdigest()[:16]+'.png'
        if word in HINTS:
            row.update(kind='native_hint',hint=HINTS[word])
        elif word in ALIASES:
            row.update(kind='shared_illustration',same_as=ALIASES[word])
        elif word in pilot_by:
            row.update(kind='pilot_illustration',source=str((PILOT/pilot_by[word]['path']).relative_to(ROOT)))
        else:
            row.update(kind='ai_illustration',scene=SCENES.get(word, f'A clear compact educational illustration of {word!r}, specifically its curriculum meaning {row["meaning"]!r}; show a concrete object or minimal human situation that conveys precisely that meaning.'))
        entries.append(row)
    names={x['word'] for x in entries}
    assert all(x.get('same_as',x['word']) in names for x in entries)
    jobs=[]
    pictures=[x for x in entries if x['kind']=='ai_illustration']
    for i in range(0,len(pictures),4):
        cells=[dict(x,index=j) for j,x in enumerate(pictures[i:i+4])]
        jobs.append({'id':f'academy-b1-{i//4+1:03}', 'cells':cells, 'status':'pending'})
    out={'format_version':1,'book_id':1,'word_count':len(entries),'width':320,'height':320,'format':'PNG','max_bytes':200000,
         'style_reference':'Design/2026-10-11-word-illustration-pilot/sources/academy-pilot-02.png',
         'words':entries,'jobs':jobs}
    path=OUT/'plan.json'
    if path.exists(): raise SystemExit('Plan already exists; do not overwrite generation progress')
    path.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
    from collections import Counter
    print(dict(Counter(x['kind'] for x in entries)),len(jobs),'atlases')

if __name__=='__main__': main()
