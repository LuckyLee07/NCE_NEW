"""Explicit sense-based choices. No spelling-based or case-insensitive reuse."""
REUSE = {}
for line in '''
vicar|2|vicar
corporation|1|company
journalist|1|reporter
palace|2|palace
impatient|2|impatiently
fantastic|2|immense
reconstruct|2|restore
high-rise|2|block
colossal|2|immense
horror|2|fright
confidently|2|confidence
dreadful|2|frightful
chalk|1|chalk
comfortable|2|comfortable
promptly|2|promptly
remarkable|2|extraordinary
hire|2|employ
appreciate|2|appreciate
prize|2|precious
theft|2|steal
ashamed|2|shame
apologize|1|sorry
agreeable|1|pleasant
locate|2|lie
suspend|2|hang
immensity|2|immense
peculiar|2|peculiar
shock|2|shock
astound|2|astonish
fame|1|famous
proceed|2|continue
varying|2|various
stack|2|pile
vessel|1|ship
temporary|2|temporarily
pride|2|proud
classify|2|sort
priest|2|vicar
consequence|2|effect
wares|2|goods
console|2|sympathetic
labourer|1|work
lovable|1|lovely
apologetic|1|sorry
contents|2|contents
item|2|article
blacken|2|blacken
reunite|1|meet
cancel|2|refuse
odd|2|strange
complaint|2|complain
clue|2|track
boulder|2|rock
petrol|2|petrol
clump|2|bush
silly|2|fool
permission|2|allow
grant|2|allow
pastoral|1|country
rapture|2|delighted
pasture|2|field
idyllic|1|pleasant
misery|2|suffer
pot-holer|2|explorer
waterfall|2|wonderful
limestone|2|stone
shiver|1|cold
rim|2|edge
rebound|2|leap
monotonous|2|dull
inspection|2|check
exhaust|1|tired
spacious|2|space
landscape|2|view
purchase|1|buy
consumer|1|customer
rust|1|rusty
helicopter|2|helicopter
hospitable|2|welcome
immaculate|1|tidy
industriousness|1|hard-working
mirth|2|laugh
cellar|2|basement
resolution|2|determined
full-time|1|work
diagnose|1|doctor
relieve|2|relieve
repetitive|2|repeat
permanent|2|endless
outlandish|2|peculiar
weird|2|strange
prompt|2|urge
safeguard|2|preserve
qualified|2|successful
alter|2|form
insect|2|bee
revulsion|1|hate
entranced|2|concentration
colony|2|colony
sticky|2|sticky
particle|2|tiny
boundary|2|border
predecessor|2|former
attic|1|upstairs
grapple|2|grab
emigrate|1|move
milestone|1|mile
reservoir|2|pool
toss|1|throw
amass|2|collect
boredom|2|dull
''' .strip().splitlines():
 word,book,source=line.split('|'); REUSE[word]=(int(book),source)
# Reject merely associated concepts: these require their own scene or diagram.
for word in 'labourer reunite cancel clue boulder silly pastoral pasture idyllic pot-holer waterfall limestone shiver rebound spacious immaculate full-time diagnose permanent qualified alter insect entranced particle attic emigrate milestone reservoir'.split(): REUSE.pop(word,None)
CAPTIONS = {
 'impatient':'He feels ___ while waiting.', 'fantastic':'The ship is a ___ size.',
 'reconstruct':'They ___ the damaged object.', 'high-rise':'This is a ___ building.',
 'colossal':'The ship is ___ beside the person.', 'horror':'She reacted in ___ to the shadow.',
 'confidently':'He spoke ___.', 'dreadful':'The smell is ___.',
 'promptly':'She answered the phone ___.', 'remarkable':'This unusual flower is ___.',
 'hire':'They will ___ a new worker.', 'appreciate':'She can ___ fine art.',
 'prize':'This is a ___ possession.', 'theft':'Taking the wallet was a ___.',
 'ashamed':'He felt ___ after his mistake.', 'apologize':'I must ___ for the accident.',
 'agreeable':'The surroundings are ___.','locate':'The village is ___d between the hills.',
 'suspend':'They ___ the picture from a hook.','immensity':'The ship’s ___ dwarfs the person.',
 'astound':'The large gift will ___ her.','fame':'The performer enjoys ___.',
 'proceed':'Please ___ with your work.','varying':'Objects of ___ kinds.',
 'stack':'Please ___ the books.','temporary':'This arrangement is ___.',
 'pride':'Parents ___ themselves on their children’s achievements.',
 'classify':'Please ___ these objects by kind.','priest':'A ___ works at the church.',
 'consequence':'What was the ___ of the change?', 'wares':'The shop sells these ___.',
 'console':'She tries to ___ her sad friend.', 'lovable':'The little animal is ___.',
 'apologetic':'He looks ___ about the spill.','item':'This is one ___ from the collection.',
 'complaint':'He made a ___ about the food.', 'permission':'The parent gives ___ to enter.',
 'grant':'The parent will ___ permission to enter.', 'rapture':'She looked at the gift with ___.',
 'misery':'He is in ___ with his headache.', 'rim':'Look at the ___ of the shape.',
 'monotonous':'The lecture is ___.','inspection':'The officer carries out an ___.',
 'exhaust':'Hard work can ___ a person.','landscape':'They admire the ___.',
 'purchase':'She will ___ the item.','consumer':'A ___ buys goods in a shop.',
 'rust':'The iron will ___ in damp air.', 'hospitable':'The host is ___ to visitors.',
 'industriousness':'Her careful work shows ___.','mirth':'Their laughter shows ___.',
 'cellar':'The room below ground is a ___.','resolution':'She faces the climb with ___.',
 'relieve':'Putting down the bag will ___ the burden.','repetitive':'The action is ___.',
 'outlandish':'The object has an ___ shape.','weird':'The two-spout teapot looks ___.',
 'prompt':'Her encouragement will ___ him to try.','safeguard':'They ___ the old object.',
 'revulsion':'He feels ___ at the unpleasant thing.','colony':'A ___ of insects lives together.',
 'boundary':'This line is the ___ between the two areas.',
 'predecessor':'The earlier manager was her ___.','grapple':'She will ___ the object firmly.',
 'toss':'He will ___ the object.','amass':'They ___ a collection of objects.',
 'boredom':'The long lecture leads to ___.',
}
DIAGRAMS = {
 'equal':{'type':'same'}, 'status':{'type':'hierarchy'},
 'consist':{'type':'container'},'span':{'type':'measure','label':'A ↔ B'},
 'length':{'type':'measure','label':'A ↔ B'}, 'alike':{'type':'same'},
 'dozen':{'type':'quantity','value':12}, 'Equator':{'type':'globe','mode':'equator'},
 'invariably':{'type':'frequency','value':7}, 'series':{'type':'sequence','value':2},
 'alongside':{'type':'location','mode':'beside'}, 'assorted':{'type':'sorting'},
 'rarity':{'type':'rarity'}, 'miniature':{'type':'size','mode':'tiny'},
 'resemblance':{'type':'same'}, 'direct':{'type':'motion','mode':'straight'},
 'steadily':{'type':'increase'},'correlate':{'type':'connect'},
 'zigzag':{'type':'pattern'},'vertically':{'type':'motion','mode':'lower'},
 'annual':{'type':'month','value':0}, 'untold':{'type':'endless'},
 'worldwide':{'type':'globe','mode':'world'},'maximum':{'type':'threshold'},
 'incessantly':{'type':'frequency','value':7},'invisible':{'type':'empty'},
 'regularity':{'type':'pattern'},'diminish':{'type':'compare','mode':'less'},
 'alternative':{'type':'replace'},'network':{'type':'connect'},
 'horde':{'type':'quantity','value':15},'cluster':{'type':'quantity','value':5},
 'infinitely':{'type':'endless'},'proportion':{'type':'fraction','value':0.25},
 'fraction':{'type':'fraction','value':0.05},'microscopic':{'type':'size','mode':'tiny'},
}
# Renderer types must express the actual concept; reject generic empty/threshold surrogates.
for word in 'Equator alongside zigzag vertically annual worldwide maximum invisible cluster horde'.split(): DIAGRAMS.pop(word,None)
CAPTIONS.update({
 'equal':'One cup will ___ one cup.','status':'He has a high ___ in the organisation.',
 'consist':'The box will ___ of these objects.','span':'The bridge has a ___ from A to B.',
 'length':'Measure the ___ from A to B.','alike':'The two cups look ___.',
 'dozen':'A ___ means twelve.','invariably':'She ___ has tea: every day.',
 'series':'This is a ___ of steps.','assorted':'These are ___ kinds of objects.',
 'rarity':'Only one is different: it is a ___.','miniature':'The small object is ___.',
 'resemblance':'The two cups have a strong ___.','direct':'Go ___ to the destination.',
 'steadily':'The number rises ___.','correlate':'We can ___ the two sets of information.',
 'untold':'There are ___ possibilities.','incessantly':'The activity happens ___.',
 'regularity':'The pattern repeats with ___.','diminish':'The amount will ___.',
 'alternative':'Choose the ___ option.','network':'Connections form a ___.',
 'infinitely':'It goes on ___.','proportion':'This ___ is part of the whole.',
 'fraction':'Only a small ___ of the whole.','microscopic':'The tiny particle is ___.',
})
HINTS={
 'somehow':'___, the animal found a way into the garden.',
 'narrowly':'The ship ___ missed the iceberg: only a small distance separated them.',
 'sarcastically':'“What lovely weather!” he said ___ during the storm.',
 'exempt':'Children are ___ from this tax: they do not have to pay.',
 'genuinely':'Her smile was sincere: she was ___ pleased.',
 'technically':'___, this was against the rules, even though no one was harmed.',
 'seemingly':'The house was ___ empty, but someone was hiding inside.',
 'emotionally':'The family valued the photograph ___, not for its price.',
 'faintly':'He could ___ hear the distant sound: it was very weak.',
 'largely':'The success was ___ due to their careful work.',
 'solely':'She did it ___ for fun: that was her only reason.',
 'exceptionally':'On this occasion, ___, the train arrived early.',
 'admittedly':'___, the plan has a weakness, but it may still succeed.',
 'positively':'He was ___ certain: there was no doubt at all.',
 'virtually':'The work is ___ finished: only one small part remains.',
 'evidently':'The ground is wet. ___, it has rained.',
 'veritable':'It was a ___ miracle: a real and remarkable event.',
 'bearing':'That detail has no ___ on our decision: it is not relevant.',
 'sheer':'It was ___ luck: nothing else caused the result.',
 'unduly':'Do not worry ___: your worry is greater than necessary.',
}
# Review the renderer's actual geometry rather than guessing from case names.
for word in ['status','network','span','length','alternative']:
 DIAGRAMS.pop(word,None)
for word in ['rim']:
 REUSE.pop(word,None)
# Proper organisations and an idiomatic degree adverb cannot be identified by a generic computer or injury drawing.
HINTS.update({
 'IBM':'International Business Machines is usually abbreviated to ___.',
 'Microsoft':'Windows is produced by the software company ___.',
 'DOS':'The older Disk Operating System was known as ___.',
 'mortally':'He was ___ offended: extremely offended, not physically injured.',
})
DIAGRAMS['series']['mode']='series'
DIAGRAMS['incessantly']['mode']='continuous'
CAPTIONS['incessantly']='The activity continues ___ without stopping.'
