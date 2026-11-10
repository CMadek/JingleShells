group="Chimney"
def spun(name,profile,m):
    loops=[[(r*cos(i*pi/24),.14+r*sin(i*pi/24),z) for i in range(48)] for z,r in profile]
    return rings(name,loops,m,closed=True)
spun("Flared chimney socket",[(1.59,.34),(1.68,.34),(1.73,.28),(1.81,.22),(1.81,.18),(1.59,.18)],bronze)
spun("Rolled chimney | hollow bore",[(1.72,.225),(1.95,.204),(2.73,.198),(2.80,.221),(2.81,.189),(2.72,.17),(1.72,.17)],iron)
for z,r in [(1.75,.256),(1.94,.219),(2.43,.215),(2.73,.221),(2.81,.233)]:
    spun("Rolled flue collar",[(z-.022,r-.008),(z-.015,r),(z+.015,r),(z+.022,r-.008),(z+.02,r-.028),(z-.02,r-.028)],bronze)
rod("Stocking rail",(-.77,-.16,2.45),(.77,-.16,2.45),.03,brass)
for x in (-.74,.74):
    rod("Rail finial",(x,-.16,2.45),(x+( .046 if x>0 else -.046),-.16,2.45),.048,bronze)
for x in (-.48,0,.48):
    wire("Forged J hook",[(x,-.16,2.45),(x,-.16,2.38),(x,-.18,2.35),(x,-.215,2.345),(x,-.24,2.36),(x,-.244,2.39)],.014,bronze)
for x in (-.17,.17):
    rod("Saddle standoff",(x,.04,2.43),(x,-.16,2.45),.033,bronze)
group="Furnace"
for y in (-.27,.30):
    jacket("Casting strap",(.836,.605,1.261,.405),(.817,.613,1.258,.390),y-.024,y+.024,bronze)
