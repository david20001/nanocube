require(polycover)
require(nanocube)
require(RColorBrewer)
library(ggplot2)

engine <- nanocube::nanocube.load(c("p1=/Users/llins/projects/compressed_nanocube/data/1M/taxi-1M-part1.nanocube",
                                    "p2=/Users/llins/projects/compressed_nanocube/data/1M/taxi-1M-part2.nanocube",
                                    "p3=/Users/llins/projects/compressed_nanocube/data/1M/taxi-1M-part3.nanocube",
                                    "p4=/Users/llins/projects/compressed_nanocube/data/1M/taxi-1M-part4.nanocube"))
nanocube::nanocube.messages(engine)

# prepare path binary representation into tile coordinates
tx_tiles <- function(location.bin, inputres, tileres)
{
	n          <- length(location.bin)
	lower.30b  <- as.integer(location.bin %% 2^30)
	higher.30b <- as.integer(location.bin  / 2^30)
	M          <- cbind(
		matrix(sapply(1:15,function(i){ bitwAnd(3,bitwShiftR(higher.30b,28 - (2 * (i-1))))}),byrow=F,nrow=n),
		matrix(sapply(1:15,function(i){ bitwAnd(3,bitwShiftR(lower.30b, 28 - (2 * (i-1))))}),byrow=F,nrow=n)
	)
	p          <- rev(2^(0:29))
	x          <- sapply(1:nrow(M), function(i) { (bitwAnd(1,M[i,]) != 0) %*% p })
	y          <- sapply(1:nrow(M), function(i) { (bitwAnd(2,M[i,]) != 0) %*% p })
	x.tile     <- bitwShiftR(x, tileres)
	y.tile     <- bitwShiftR(y, tileres)
	side       <- 2^tileres
	x.pixel    <- bitwAnd(side-1,x)
	y.pixel    <- bitwAnd(side-1,y)
	x.tile0    <- min(x.tile)
	y.tile0    <- min(y.tile)
	x.img      <- (x.tile - x.tile0) * side + x.pixel
	y.img      <- (y.tile - y.tile0) * side + y.pixel
        width      <- max(x.tile) - min(x.tile) + 1
        height     <- max(y.tile) - min(y.tile) + 1

	list( 
		inputres=inputres,
		tilelevel=tilelevel,
		tileres=tileres,
		tileside=side,
		imgwidth=width * side,
		imgheight=height * side,
		records= data.frame(
			xtile=x.tile,   ytile=y.tile,
			xpixel=x.pixel, ypixel=y.pixel, 
			ximg=x.img,     yimg=y.img))

}

tx_img <- function(tx_tiles_data, values)
{
	m <- matrix(0,tx_tile_data$imgwidth,tx_tiles_data$height)
	for (i in 1:length(x)) {
	    m[1+x[i], 1+y[i]] = values[i]
	}
	m
}

tx_query <- function(engine, dataset, lat, lon, tillevel, tileres, tilexrange, tileyrange) 
{
	base            <-  polycover::pc.d2c(cbind(lon,lat),tilelevel)
	xx              <-  base[,1] + tilexrange
	yy              <-  base[,2] + tileyrange
	tiles           <-  cbind(expand.grid(xx,yy),tilelevel)
	
	query.result    <- lapply(1:nrow(tiles),
	function(i) {
	nanocube::nanocube.query(engine,
			sprintf("%s
			        .b(\"pickup_location\",dive(tile2d(%d,%d,%d),%d));",
			        # .b(\"dropoff_location\",dive(tile2d(%d,%d,%d),%d));",
			        #       			.b(\"pickup_location\",tile2d(16,19295,40896))
			        dataset, tiles[i,3],tiles[i,1],tiles[i,2],tileres))
	})

	# merge all query results into a signle data frame
	query.result     <- Reduce(function(a,b) { rbind(a,b)}, query.result)
	
	location.bin     <- query.result[,1]
	values           <- query.result[,2:ncol(query.result)]

	augmented.result <- tx_tiles(location.bin, tilelevel + tileres, tileres)
	augmented.result$records <- cbind(augmented.result$records, values)
	
	# sort records by
	pi = order(augmented.result$records$ximg,augmented.result$records$yimg)
	augmented.result$records <- augmented.result$records[pi,]
	
	augmented.result
}

# http://a.tile.openstreetmap.org/12/1205/1540.png
lat             <-  40.716594
lon             <- -74.006081
tilelevel       <-  14
tilexrange      <- -2:7
tileyrange      <- -5:6
tileres         <-  6

data1           <- tx_query(engine, "p1", lat, lon, tilelevel, tileres, tilexrange, tileyrange)
data2           <- tx_query(engine, "p2", lat, lon, tilelevel, tileres, tilexrange, tileyrange)
data3           <- tx_query(engine, "p3", lat, lon, tilelevel, tileres, tilexrange, tileyrange)
data4           <- tx_query(engine, "p4", lat, lon, tilelevel, tileres, tilexrange, tileyrange)
records         <- rbind(data.frame(data1$records,source=1),
                         data.frame(data2$records,source=2),
                         data.frame(data3$records,source=3),
                         data.frame(data4$records,source=4))

min.xtile        <- min(records$xtile)
min.ytile        <- min(records$ytile)
records$ximg = (records$xtile - min.xtile) * 2^tileres + records$xpixel
records$yimg = (records$ytile - min.ytile) * 2^tileres + records$ypixel

selection       <- records$count > 0
records         <- records[selection,]
values          <- records$source

#fare/records$count

v <- ggplot(records, aes(ximg, yimg))
v + geom_point(aes(color=factor(records$source)),size=1) + coord_fixed(ratio = 1) + scale_colour_brewer(palette = "Set1")





+ scale_colour_manual(values = c("red","blue", "green"))

scale_colour_brewer(palette = "Set1")


+ scale_colour_manual(values=c("#CC6666", "#9999CC", "#66CC99", "red"))
v + geom_raster(aes(fill=records$source)) + scale_fill_manual(values=c("#CC6666", "#9999CC", "#66CC99"))


# fare     <- img.it(data, depth, "fare")
# count    <- img.it(data, depth, "count")
# image(values, col = grey(seq(0, 1, length = 256)), axes = FALSE, asp=1)
# image(log(1+(fare/(1+count))), col = grey(seq(0, 1, length = 256)), axes = FALSE, asp=1)
# filled.contour(values, asp=1, frame.plot=F,  nlevels=5, col=brewer.pal(7,"YlOrRd"),
# col=c(1,2,3,4,5,6),
#               plot.axes = contour(values,add=T,nlevels=7))
# v + geom_contour()
# v + geom_density_2d()



















# inputres        <-  tilelevel + tileres
# base            <-  polycover::pc.d2c(cbind(lon,lat),tilelevel)
# xx              <-  base[,1] + xrange
# yy              <-  base[,2] + yrange
# tiles           <-  cbind(expand.grid(xx,yy),tilelevel)
# colnames(tiles) <-  c("x","y","level")

#
# results.hi  <- lapply(1:nrow(tiles),
# 	function(i) {
# 	nanocube::query(engine,
# 			sprintf("taxi
#       .b(\"pickup_location\",tile2d(16,19295,40896))
# 			.b(\"dropoff_location\",dive(tile2d(%d,%d,%d),8));",tiles[i,3],tiles[i,1],tiles[i,2]))
# 	})



# now create a matrix with the correct values
# data.hi   <- run(8)
# fare.hi   <- img.it(data.lo, "count")
# count.hi  <- img.it(data.lo, "distance")

