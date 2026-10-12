import AppKit
import ImageIO
// Native educational diagrams: exact counts, calendars and timelines; no generated art is edited.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let bookID = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 1
let plan = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("ContentPipeline/word-images/academy-book\(bookID)/plan.json"))) as! [String:Any]
let words = (plan["words"] as! [[String:Any]]).filter { ($0["kind"] as? String) == "native_diagram" }
let ink = NSColor(srgbRed:0.13,green:0.24,blue:0.33,alpha:1)
let blue = NSColor(srgbRed:0.13,green:0.49,blue:0.73,alpha:1)
let pale = NSColor(srgbRed:0.88,green:0.94,blue:0.98,alpha:1)
let grey = NSColor(srgbRed:0.72,green:0.78,blue:0.81,alpha:1)
let orange = NSColor(srgbRed:0.90,green:0.55,blue:0.24,alpha:1)
// Public drawing helpers take coordinates measured down from the top.
func rect(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat)->NSRect { NSRect(x:x,y:320-y-h,width:w,height:h) }
func box(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ fill:NSColor,_ radius:CGFloat=10,_ stroke:NSColor?=nil) {
 let p=NSBezierPath(roundedRect:rect(x,y,w,h),xRadius:radius,yRadius:radius);fill.setFill();p.fill()
 if let s=stroke {s.setStroke();p.lineWidth=2;p.stroke()}
}
func line(_ x:CGFloat,_ y:CGFloat,_ x2:CGFloat,_ y2:CGFloat,_ c:NSColor=ink,_ width:CGFloat=3) {
 let p=NSBezierPath();p.move(to:NSPoint(x:x,y:320-y));p.line(to:NSPoint(x:x2,y:320-y2));p.lineWidth=width;p.lineCapStyle = .round;c.setStroke();p.stroke()
}
func dot(_ x:CGFloat,_ y:CGFloat,_ r:CGFloat,_ c:NSColor) {c.setFill();NSBezierPath(ovalIn:rect(x-r,y-r,2*r,2*r)).fill()}
func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ size:CGFloat=24,_ c:NSColor=ink) {
 let p=NSMutableParagraphStyle();p.alignment = .center
 (s as NSString).draw(in:rect(x,y,w,size*1.5),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:c,.paragraphStyle:p])
}
func arrow(_ x:CGFloat,_ y:CGFloat,_ x2:CGFloat,_ y2:CGFloat,_ c:NSColor=blue) {
 line(x,y,x2,y2,c);let a=atan2(y2-y,x2-x)
 line(x2,y2,x2-9*cos(a-0.5),y2-9*sin(a-0.5),c);line(x2,y2,x2-9*cos(a+0.5),y2-9*sin(a+0.5),c)
}
func cup(_ x:CGFloat,_ y:CGFloat,_ s:CGFloat=1,_ c:NSColor=blue) {
 let handle=NSBezierPath(ovalIn:rect(x+25*s,y+6*s,14*s,20*s));c.setStroke();handle.lineWidth=3*s;handle.stroke()
 box(x,y,30*s,35*s,c,5*s);line(x-3*s,y+39*s,x+37*s,y+39*s,ink,2*s)
}
func person(_ x:CGFloat,_ y:CGFloat,_ c:NSColor=blue) {dot(x,y,8,c);box(x-10,y+12,20,26,c,6);line(x-5,y+37,x-5,y+52,c,5);line(x+5,y+37,x+5,y+52,c,5)}
func book(_ x:CGFloat,_ y:CGFloat,_ c:NSColor=blue) {box(x,y,44,58,c,4,ink);line(x+8,y+2,x+8,y+56,ink,2);line(x+15,y+16,x+34,y+16,.white,2)}
func check(_ x:CGFloat,_ y:CGFloat,_ c:NSColor=blue) {line(x-6,y,x-1,y+5,c,3);line(x-1,y+5,x+8,y-6,c,3)}
func calendar(_ month:Int) {
 box(29,27,262,267,.white,18,ink);box(29,27,262,49,pale,16)
 for x:CGFloat in [87,233] {line(x,18,x,42,ink,6)}
 text("12 MONTHS",60,39,200,21,blue)
 for i in 1...12 {let x=CGFloat((i-1)%3)*75+53,y=CGFloat((i-1)/3)*46+91
  box(x,y,64,36,month==i || month==0 ? blue : pale,8);text(String(i),x,y+3,64,21,month==i || month==0 ? .white : ink)
 }
}
func weekdays(_ selected:Int) {
 box(17,63,286,198,.white,16,ink);box(17,63,286,45,pale,14)
 text("M      T      W      T      F      S      S",24,74,272,17)
 for i in 0..<7 {let x=CGFloat(i)*38+28;let on=selected==8 || selected==i || selected==7 && i>=5
  box(x,126,29,55,on ? blue:pale,7);if on {check(x+14,153,.white)}
 }
 if selected==8 {text("7 × 24 h",50,210,220,26,blue)}
 else if selected==7 {line(224,203,285,203,orange,4);text("5 + 2 days",50,218,220,24)}
 else {text("\(selected+1) / 7",50,211,220,26,blue)}
}
func clock(_ mode:String) {
 let p=NSBezierPath(ovalIn:rect(60,40,200,200));pale.setFill();p.fill();ink.setStroke();p.lineWidth=3;p.stroke()
 for n in 1...12 {let a=CGFloat(n)*(.pi/6)-(.pi/2);let x=160+83*cos(a),y=140+83*sin(a);text(String(n),x-15,y-13,30,17)}
 if mode=="hour" {line(160,140,216,140,ink,6);line(160,140,160,69,blue,4);text("3:00",70,259,180,30,blue)}
 else if mode=="hand" {line(160,140,216,140,grey,5);line(160,140,160,73,blue,6);arrow(219,92,174,91,orange)}
 else {line(160,140,160,73,blue,4);line(160,140,117,166,ink,5)
  let path=NSBezierPath();path.appendArc(withCenter:NSPoint(x:160,y:180),radius:68,startAngle:90,endAngle:mode=="minute" ? -260 : 60,clockwise:true);orange.setStroke();path.lineWidth=4;path.stroke()
  text(mode=="minute" ? "60 s" : "…",40,259,240,27,blue)
 }
 dot(160,140,6,ink)
}
func timeline(_ mode:String) {
 let y:CGFloat=157
 arrow(30,y,293,y,grey);var left="",right="",a:CGFloat=80,b:CGFloat=245
 switch mode {
 case "now":left="PAST";right="FUTURE";a=160;b=160
 case "ago":left="−2 years";right="NOW";a=70;b=249
 case "since":left="2020";right="NOW";a=65;b=254
 case "till":left="09:00";right="17:00";a=65;b=254
 case "during":left="START";right="END";a=65;b=254
 case "how long":left="START";right="END";a=65;b=254
 case "recently":left="−2 days";right="NOW";a=209;b=254
 case "duration":left="09:00";right="10:00";a=65;b=254
 case "soon":left="NOW";right="+";a=90;b=158
 default:left="NOW";right="+";a=65;b=255
 }
 if mode=="duration" {text("1 h",110,91,100,32,blue)}
 if mode=="ago" || mode=="recently" {arrow(b,y-23,a,y-23,blue)}
 else if mode=="now" {dot(160,y,13,blue);arrow(160,90,160,131,blue)}
 else {line(a,y,b,y,blue,7);dot(a,y,6,ink);dot(b,y,8,blue)}
 if mode=="during" {dot(157,y,13,orange);arrow(157,95,157,133,orange)}
 if mode=="how long" {text("?",115,78,90,44,blue)}
 text(left,15,187,112,19);text(right,200,187,105,19)
 if mode=="now" {text("●",130,208,60,28,blue)}
 if mode=="soon" || mode=="later" {cup(b-15,82,0.8);text("…",120,210,80,26,grey)}
}
func render(_ w:[String:Any]) throws {
 let d=w["diagram"] as! [String:Any],t=d["type"] as! String,v=(d["value"] as? NSNumber)?.intValue ?? 0
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:320,pixelsHigh:320,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
 NSColor.white.setFill();NSRect(x:0,y:0,width:320,height:320).fill()
 switch t {
 case "month":calendar(v)
 case "weekday":weekdays(v)
 case "clock":clock(d["mode"] as! String)
 case "timeline":timeline(d["mode"] as! String)
 case "quantity":
  if v==100 {for i in 0..<100 {box(CGFloat(i%10)*23+48,CGFloat(i/10)*23+38,17,17,blue,3)};text("10 × 10",65,276,190,23)}
  else {let cols=min(v,5),rows=(v+cols-1)/cols
   for i in 0..<v {cup(CGFloat(i%cols)*51+CGFloat(320-cols*51)/2+6,CGFloat(i/cols)*65+CGFloat(320-rows*65)/2,0.95)}
  }
 case "same":cup(58,126,1.5);cup(211,126,1.5);text("=",131,133,55,42,blue)
 case "compare":
  for i in 0..<2 {let x:CGFloat = i==0 ? 47:201;box(x,81,72,160,.white,8,ink);let h:CGFloat = i==0 ? 128:49;box(x+4,237-h,64,h,i==0 ? pale:blue,4)}
  arrow(143,163,179,163)
 case "liquid":
  box(111,56,98,197,.white,8,ink);let h:CGFloat = floor(187 * CGFloat((d["value"] as? NSNumber)?.doubleValue ?? 0.2));box(115,249-h,90,h,pale,5);line(115,248-h,205,248-h,blue,3)
  for y in stride(from:88,through:210,by:41) {line(192,CGFloat(y),205,CGFloat(y),grey,2)}
 case "enough":
  for i in 0..<4 {let x=CGFloat(i)*65+62;person(x,66);arrow(x,132,x,162,grey);cup(x-16,189,1)}
 case "subset":
  let mode=d["mode"] as! String
  for i in 0..<6 {let x=CGFloat(i%3)*78+62,y=CGFloat(i/3)*87+77
   cup(x,y,1,mode=="rest" && i<2 || mode=="except" && i==4 ? grey:blue)
   if mode=="rest" && i<2 {arrow(x+9,y-13,x+9,y-33,grey)}
   if mode=="except" && i==4 {line(x-5,y-5,x+34,y+39,orange,3)}
   if mode=="all" {check(x+13,y+58)}
  }
 case "empty":box(56,91,208,144,pale,18,ink);box(70,106,180,111,.white,15,grey);text("0",104,135,112,44,blue)
 case "replace":cup(59,127,1.5,grey);line(54,119,114,189,orange,3);arrow(139,155,190,155);cup(217,127,1.5)
 case "distance":person(57,153);cup(105,166,1);cup(241,166,0.65,grey);arrow(67,174,102,174);box(96,151,59,65,.clear,9,blue)
 case "frequency":
  if (d["mode"] as? String)=="continuous" {
   // A connected waveform shows uninterrupted activity; daily checkmarks do not.
   for i in 0..<48 {
    let x=CGFloat(i)*5+35, y=151+sin(CGFloat(i) * .pi/4)*29
    let x2=CGFloat(i+1)*5+35, y2=151+sin(CGFloat(i+1) * .pi/4)*29
    line(x,y,x2,y2,blue,4)
   }
   arrow(276,151,294,151,blue);text("∞",99,217,122,63,blue)
  } else {
  cup(140,43,1);text("1     2     3     4     5     6     7",23,132,274,20)
  for i in 0..<7 {let x=CGFloat(i)*39+26;let on = v==2 ? (i==1 || i==5) : i<v
   box(x,175,31,51,on ? pale : .white,7,grey);if on {check(x+15,201)}else{line(x+7,200,x+23,200,grey,2)}
  }
  }
 case "repeat":
  for i in 0..<v {let x=CGFloat(i)*87+CGFloat(320-v*87)/2+20;cup(x,124);text(String(i+1),x-5,187,50,23);if i<v-1 {arrow(x+48,145,x+67,145,grey)}}
 case "progress":box(38,119,244,58,.white,10,ink);box(43,124,211,48,blue,6);line(278,99,278,191,orange,3);text("90 / 100",55,209,210,27)
 case "number":box(69,74,182,170,pale,18,ink);text("No.",102,101,116,24);text("27",90,143,140,60,blue)
 case "address":
  box(43,57,234,199,pale,14,ink);box(62,77,196,61,.white,8);text("12",72,88,176,37,blue);text("King Street",50,158,220,28);line(70,212,250,212,grey,2)
 case "worth":book(62,130);arrow(126,159,172,159);box(191,120,84,78,pale,10,ink);text("£5",195,139,76,32,blue)
 case "mile":line(48,142,272,142,ink,9);line(48,110,48,181,blue,3);line(272,110,272,181,blue,3);text("1 mi",65,67,190,34,blue);text("≈ 1.609 km",30,211,260,27)
 case "minimum":
  for i in 0..<3 {cup(CGFloat(i)*56+41,132,1)};text("+",220,125,58,42,grey);text("≥ 3",70,216,180,30,blue)
 case "latest":
  for i in 0..<3 {let x=CGFloat(i)*99+27;book(x,119,i==2 ? blue:grey);text(String(2024+i),x-10,190,65,20,i==2 ? blue:ink);if i<2 {arrow(x+55,149,x+77,149,grey)}}
 case "fraction":
  let fraction=(d["value"] as? NSNumber)?.doubleValue ?? 1
  if fraction==1 {
   // Retain the reviewed whole diagram's pixels for existing books.
   dot(160,155,94,blue);for a:CGFloat in [0,.pi/2,.pi,3 * .pi/2] {line(160,155,160+94*cos(a),155+94*sin(a),.white,3)};text("1 = 4/4",50,268,220,24)
  } else {
   precondition(fraction>=0 && fraction<1,"Fraction must be between zero and one")
   let percent=Int((fraction*100).rounded())
   precondition(abs(fraction*100-Double(percent))<0.000001,"Fraction must be an exact percentage")
   dot(160,155,94,pale)
   if fraction>0 {
    let sector=NSBezierPath();sector.move(to:NSPoint(x:160,y:165))
    sector.appendArc(withCenter:NSPoint(x:160,y:165),radius:94,startAngle:90,endAngle:90-CGFloat(fraction)*360,clockwise:true)
    sector.close();blue.setFill();sector.fill()
    line(160,155,160,61,.white,3)
    let end=CGFloat(fraction)*2 * .pi - .pi/2
    line(160,155,160+94*cos(end),155+94*sin(end),.white,3)
   }
   var numerator=percent,denominator=100,a=numerator,b=denominator
   while b != 0 {let remainder=a%b;a=b;b=remainder}
   numerator/=a;denominator/=a
   text("\(numerator)/\(denominator) = \(percent)%",28,268,264,24)
  }
 case "different":cup(54,124,1.6);box(210,124,57,57,orange,3,ink);text("≠",132,128,55,44)
 case "location":
  box(48,62,224,194,pale,12,ink);let mode=d["mode"] as! String
  if mode=="centre" {line(160,75,160,243,grey,2);line(60,159,260,159,grey,2);dot(160,159,12,blue)}
  else if mode=="edge" {line(48,63,48,255,orange,7);arrow(102,160,57,160,orange)}
  else if mode=="beneath" {box(67,107,186,15,ink,3);dot(160,196,16,blue);arrow(160,145,160,174)}
  else {dot(217,184,12,blue);arrow(215,111,217,164)}
 case "measure":
  person(58,131);person(263,131);line(58,209,263,209,blue,3);line(58,196,58,222);line(263,196,263,222);text("A ↔ B",60,245,200,28)
 case "hierarchy":
  line(47,284,190,31,blue,22);line(110,175,284,130,grey,8);line(82,224,28,95,grey,8);arrow(141,158,177,95,orange)
 case "highlight":
  box(56,46,208,234,.white,12,ink);for i in 0..<5 {let y=CGFloat(i)*34+80;if i==2 {box(70,y-3,180,24,pale,4);dot(83,y+9,5,orange)};line(100,y+9,233,y+9,i==2 ? blue:grey,4)}
 case "area":
  for i in 0..<16 {box(62+CGFloat(i%4)*49,56+CGFloat(i/4)*49,46,46,pale,2,blue)};text("4 × 4 = 16",44,266,232,27)
 case "causality":
  box(31,100,86,106,pale,10);box(203,100,86,106,pale,10);dot(73,152,23,orange);box(227,131,40,42,blue,4);arrow(126,155,190,155)
  let cause=(d["mode"] as! String)=="cause";box(cause ? 27:199,96,94,114,.clear,12,orange);text("A → B",70,243,180,27)
 case "sum":
  for i in 0..<2 {dot(CGFloat(i)*29+57,97,10,blue)};text("+",135,77,50,32);for i in 0..<3 {dot(CGFloat(i)*29+207,97,10,blue)};line(39,150,281,150,grey,2);for i in 0..<5 {dot(CGFloat(i)*42+77,211,13,blue)};text("2 + 3 = 5",45,264,230,27)
 case "age":
  person(82,167);person(230,120);arrow(111,180,198,151);text("2016",33,239,98,24);text("2026",181,239,98,24);text("10 years",71,43,178,31,blue)
 case "container":
  box(38,58,244,206,pale,15,ink);book(78,104);cup(161,143);dot(231,99,18,orange);box(52,247,216,12,blue,4)
 case "pattern":
  for i in 0..<25 {let x=CGFloat(i%5)*49+62,y=CGFloat(i/5)*49+57;if i%2==0 {dot(x,y,15,blue)}else{box(x-14,y-14,28,28,orange,3)}}
 case "rotation":
  cup(51,128,1.5);arrow(129,100,207,100);box(223,128,45,52,blue,6);line(219,120,280,120,ink,3);let p=NSBezierPath(ovalIn:rect(259,140,21,30));blue.setStroke();p.lineWidth=4;p.stroke();text("180°",105,225,110,28)
 case "rarity":
  for i in 0..<36 {dot(CGFloat(i%6)*43+53,CGFloat(i/6)*43+49,12,i==21 ? orange:grey)};box(166,165,33,33,.clear,8,orange)
 case "motion":
  let mode=d["mode"] as! String
  if mode=="lower" {box(111,53,98,41,pale,7,grey);arrow(160,109,160,198);box(111,222,98,41,blue,7)}
  else if mode=="ahead" {person(88,162,grey);person(215,162);arrow(97,250,236,250);box(191,148,48,81,.clear,8,orange)}
  else if mode=="distant" {person(45,143);box(265,155,25,32,pale,3,ink);line(72,230,281,230,grey,2);text("10 km",104,247,126,25)}
  else {person(50,136);box(239,128,46,65,pale,5,ink);arrow(84,161,220,161);if mode=="straight" {line(84,204,220,204,grey,2)}}
 case "viewfield":
  let p=NSBezierPath();p.move(to:NSPoint(x:61,y:162));p.line(to:NSPoint(x:277,y:251));p.line(to:NSPoint(x:277,y:73));p.close();pale.setFill();p.fill();dot(59,158,16,ink);dot(61,158,8,.white);dot(63,158,5,blue);book(219,132);line(65,151,277,69,grey,2);line(65,165,277,247,grey,2)
 case "threshold":
  line(37,151,281,151,orange,3);text("100",22,111,66,23,orange);for (i,h) in [55,100,139].enumerated() {box(CGFloat(i)*82+50,251-CGFloat(h),46,CGFloat(h),h>=100 ? blue:grey,5)}
 case "sequence":
  for i in 0..<3 {let x=CGFloat(i)*96+32;let active=(d["mode"] as? String)=="series" || (v==0 ? i==0:i==v-1);box(x,120,66,66,active ? blue:pale,12);text(String(i+1),x,135,66,30,active ? .white:ink);if i<2 {arrow(x+73,153,x+87,153,grey)}};if v==0 {text("PAST → NOW",42,226,236,25)}else if v==3 {check(253,223)}
 case "oneperson":box(36,65,248,209,pale,15);person(160,120);dot(160,244,4,grey)
 case "globe":
  let mode=d["mode"] as! String
  if mode=="atmosphere" {dot(160,157,123,pale)};dot(160,157,91,blue)
  let p=NSBezierPath(ovalIn:rect(121,66,78,182));grey.setStroke();p.lineWidth=2;p.stroke();line(70,157,250,157,grey,2)
  if mode=="pole" {dot(160,66,9,orange);dot(160,248,9,orange);text("N",138,25,44,24);text("S",138,266,44,24)}else{arrow(282,44,247,80,orange)}
 case "endless":text("∞",26,75,268,130,blue);arrow(40,252,282,252,grey)
 case "percent":
  for i in 0..<100 {box(CGFloat(i%10)*23+48,CGFloat(i/10)*23+28,17,17,i<v ? blue:pale,3)};text("25 / 100 = 25%",21,269,278,25)
 case "normal":
  for i in 0..<7 {let x=CGFloat(i)*38+28;person(x,139,i==3 ? blue:grey)};box(126,125,32,81,.clear,8,blue);text("36.5 °C",61,235,198,28)
 case "parallel":
  for y:CGFloat in [105,213] {arrow(48,y,279,y,grey);line(86,y,234,y,blue,6);dot(86,y,6,blue);dot(234,y,6,blue)};line(86,68,86,249,orange,2);line(234,68,234,249,orange,2);book(136,31);line(133,166,173,147,ink,5)
 case "unit":
  let label=d["label"] as! String,e=d["equivalent"] as! String
  if label=="100" {box(39,41,242,245,.white,15,ink);box(39,41,242,49,pale,14);for x:CGFloat in [90,230] {line(x,28,x,58,ink,5)};text("100",33,109,254,65,blue);text("years",33,211,254,32)}
  else {box(29,83,262,139,pale,13,ink);text(label,38,100,244,38,blue);text("=",40,156,40,26);text(e,81,155,194,27);if label != "1 hp" {for i in 0..<13 {line(CGFloat(i)*19+46,227,CGFloat(i)*19+46,i%3==0 ? 248:239,ink,2)}}}
 case "space":
  box(32,62,256,204,pale,14,ink);box(46,82,54,157,blue,4);box(220,82,54,157,blue,4);arrow(113,159,209,159,orange);line(113,149,113,169,orange,2)
 case "voltage":
  box(97,77,126,175,pale,12,ink);box(139,62,42,15,ink,3);text("+",122,91,76,38);text("1.5 V",103,149,114,30,blue);text("−",122,203,76,33)
 case "size":dot(85,150,55,grey);dot(238,150,5,blue);arrow(237,86,237,131,orange)
 case "increase":
  for (i,h) in [45,91,147].enumerated(){box(CGFloat(i)*81+41,259-CGFloat(h),47,CGFloat(h),blue,5)};arrow(47,175,266,53,orange)
 case "numbervalue":
  box(21,83,278,134,pale,14);text("1,000 × 1,000,000",29,112,262,25);text("= 1,000,000,000",28,166,264,26,blue)
 case "patch":box(33,49,254,227,pale,15);box(172,168,53,41,blue,9);arrow(234,118,205,159,orange)
 case "sorting":
  for i in 0..<3 {let x=CGFloat(i)*95+26;box(x,62,80,196,pale,10);for j in 0..<3 {let y=CGFloat(j)*56+98;if i==0 {dot(x+40,y,16,blue)}else if i==1{box(x+23,y-16,34,32,orange,4)}else{cup(x+24,y-16,0.9)}}}
 case "level":
  box(28,158,264,112,pale,4);line(29,158,291,158,blue,5);arrow(162,78,162,145,orange);for i in 0..<5 {line(CGFloat(i)*49+38,201,CGFloat(i)*49+60,201,grey,2)}
 case "double":cup(46,136,1.2);arrow(107,156,154,156);cup(184,136,1.2);cup(244,136,1.2);text("× 2",109,225,102,30,blue)
 case "connect":box(40,114,75,75,pale,12,ink);box(206,114,75,75,pale,12,ink);line(114,151,206,151,blue,8);dot(114,151,8,blue);dot(206,151,8,blue)
 case "versus":person(65,127);person(255,127,orange);arrow(91,157,130,157);arrow(229,157,190,157,orange);text("VS",128,132,64,36)
 case "accuracy":
  for (r,c) in [(CGFloat(97),pale),(CGFloat(65),blue),(CGFloat(33),.white)] {dot(160,158,r,c)};dot(160,158,9,orange);arrow(261,60,160,158,ink)
 case "per":for i in 0..<3 {let x=CGFloat(i)*91+69;person(x,66);arrow(x,135,x,170,grey);cup(x-15,202)}
 case "average":
  for (i,h) in [60,120,180].enumerated(){box(CGFloat(i)*84+45,262-CGFloat(h),44,CGFloat(h),pale,4,blue);text(String(h/30),CGFloat(i)*84+40,267,54,24)};line(28,142,292,142,orange,4);text("(2 + 4 + 6) ÷ 3 = 4",14,22,292,23)
 case "border":box(30,58,130,212,pale,9);box(161,58,129,212,NSColor(srgbRed:0.97,green:0.9,blue:0.8,alpha:1),9);line(160,58,160,270,orange,5);arrow(227,157,175,157,ink)
 case "slice":
  box(37,98,159,126,pale,12,ink);for x:CGFloat in [78,119,160] {line(x,102,x,220,grey,2)};box(239,98,37,126,blue,7,ink);arrow(189,254,255,254)
 case "profit":
  text("£10",29,92,103,34,blue);text("−",128,94,45,32);text("£7",179,92,105,34);line(40,158,280,158,grey,2);text("= £3",64,192,192,48,blue);text("SALE       COST",27,53,266,20)
 case "layers":for i in 0..<5 {box(41,58+CGFloat(i)*42,238,35,i%2==0 ? pale:blue,5,ink)};arrow(291,160,268,160,orange)
 default:fatalError("Unhandled diagram \(t)")
 }
 NSGraphicsContext.restoreGraphicsState()
 let data=rep.representation(using:.png,properties:[:])!;precondition(data.count<=200000)
 try data.write(to:root.appendingPathComponent("NCE_ALL/data/words/png/"+(w["filename"] as! String)))
}
for w in words {try render(w)}
print("Rendered \(words.count) native diagrams as 320 × 320 lossless PNG.")
