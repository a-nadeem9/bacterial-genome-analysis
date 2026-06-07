import sys
import toytree
import toyplot.png

# --- Get command line arguments ---
tree_file = sys.argv[1]
output_png = sys.argv[2]

# --- Read and draw the tree ---
# Load the newick tree from file
tree = toytree.tree(tree_file)

# Draw the tree to a canvas object
canvas, axes, mark = tree.draw(
    width=800, 
    height=600,
    tip_labels_align=True
)

canvas.style = {"background-color": "white"}

# Save the canvas to a PNG file using the toyplot renderer
toyplot.png.render(canvas, output_png)
