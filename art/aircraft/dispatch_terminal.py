"""Port-side dispatch desk. From the aisle the chart is left of the CRT."""
group("07b Dispatch office")
case=mat("Dispatch field grey enamel",(.16,.205,.165),.32,.48)
phosphor=mat("Green phosphor glass",(.016,.082,.051),.12,.33,.38)
indicator=mat("Terminal pilot lamp",(.38,.86,.40),.03,.35,1.8)
cork=surfaces.material("Dispatch board cork",(.32,.181,.086),"wood",.64)
front=(pi/2,0,pi/2)

# Broad rubber feet, folded cabinet seams and a serviceable fan housing.
y=1.72
box("Terminal kick plate",(-3.70,y,.12),(.94,1.30,.22),iron,.06)
box("Terminal cabinet",(-3.69,y,.98),(1.03,1.45,1.66),case,.09)
box("Terminal drawer inset",(-3.162,y,.59),(.034,1.19,.55),iron,.025)
box("Terminal drawer face",(-3.14,y,.60),(.035,1.12,.47),case,.022)
rod("Terminal drawer grip",(-3.105,y-.19,.73),(-3.105,y+.19,.73),.026,steel,18)
box("Terminal CRT housing",(-3.72,y,1.93),(1.08,1.56,1.11),case,.11)
box("Terminal CRT hood",(-3.176,y-.12,1.96),(.17,1.02,.77),iron,.078)
box("Terminal phosphor tube",(-3.08,y-.12,1.96),(.07,.91,.63),phosphor,.032)
rig("TerminalScreen",(-3.039,y-.12,1.96))
for h in range(7):
    box("Receiver grille slot",(-3.173,y+.54,1.80+h*.047),(.026,.27,.016),iron,.006)
for z in (1.69,2.24):
    rod("Tuning knob",(-3.19,y+.53,z),(-3.10,y+.53,z),.065,iron,24)
    box("Knob witness mark",(-3.094,y+.53,z+.028),(.009,.014,.041),cream,.002)
box("Keyboard tray",(-3.01,y,1.13),(.80,1.49,.13),case,.05)
box("Keyboard gasket",(-2.99,y,1.205),(.49,1.23,.04),iron,.023)
for row in range(4):
    for col in range(12 if row<3 else 5):
        width=.087 if row<3 or col!=2 else .40
        ky=y+(col-5.5)*.099 if row<3 else y+[-.51,-.39,0,.39,.51][col]
        box("Bakelite key",(-3.16+row*.105,ky,1.244),(.080,width,.044),cream_coat if row==0 else leather,.011)
for i in range(3):
    rod("Status jewel",(-3.177,y-.48+i*.13,2.378),(-3.15,y-.48+i*.13,2.378),.023,indicator if i==0 else amber,16)
label("Manufacturer plate","NORTH STAR   /   D-48",(-3.151,y+.19,2.377),front,.054,cream)
for dy in (-.62,.62):
    for z in (.30,1.45,2.37):
        rod("Captive case screw",(-3.18,y+dy,z),(-3.145,y+dy,z),.022,steel,8)
rig("DeliveryControls",(-2.62,y,1.30))

by=-.37
box("Dispatch board backing",(-3.88,by,1.82),(.15,2.34,1.70),wood[2],.035)
box("Tack board cork",(-3.79,by,1.82),(.04,2.22,1.58),cork,.018)
for dy in (-1.14,1.14):box("Board metal binding",(-3.77,by+dy,1.82),(.08,.055,1.69),gold,.012)
for z in (.99,2.65):box("Board metal binding",(-3.77,by,z),(.08,2.30,.05),gold,.010)
label("Chart board header","DISPATCH   /   FLIGHT CHART",(-3.757,by,2.52),front,.079,cream)
label("Empty board instruction","PIN SURVEY HERE",(-3.754,by,1.83),front,.098,iron)
rig("ChartBoard",(-3.73,by,1.80))
# The clips sit on top of the mounted paper, with a small shadow underneath.
for dy in (-.93,.93):
    for z in (1.23,2.37):
        rod("Map tack",(-3.748,by+dy,z),(-3.694,by+dy,z),.037,berry if dy<0 else gold,16)
for dy in (-.9,.9):
    for z in (1.19,2.43):
        rod("Board wall standoff",(-4.66,by+dy,z),(-3.94,by+dy,z),.054,iron,12)
