import sys, json
from PIL import Image
im = Image.open(sys.argv[1]).convert("L")
names = ["Very Low","Low","Neutral","Good","Great"]
bg = 236  # parchment luminance approx
out = {}
for size, top in ((40,0),(24,50)):
    crops = [im.crop((i*50, top, i*50+size, top+size)) for i in range(5)]
    px = [list(c.getdata()) for c in crops]
    m = {}
    for n, p in zip(names, px):
        m[n] = {"dark_ink_pct": round(100*sum(v<110 for v in p)/len(p),1),
                "marked_pct": round(100*sum(abs(v-bg)>18 for v in p)/len(p),1),
                "mean_lum": round(sum(p)/len(p),1)}
    diff = {}
    for i in range(5):
        for j in range(i+1,5):
            diff[f"{names[i]} vs {names[j]}"] = round(sum(abs(a-b) for a,b in zip(px[i],px[j]))/len(px[i]),1)
    out[size] = {"per_symbol": m, "pairwise_mean_abs_diff": diff}
print(json.dumps(out, indent=1))
