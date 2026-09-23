library(sp)
library(gstat)
library(sf)
library(mapview)
library(geoR)
library(ggplot2)

data(meuse)
data(meuse.grid)

meuse <- st_as_sf(meuse, coords = c("x", "y"), crs = 28992)
mapview(meuse, zcol = "zinc",  map.types = "CartoDB.Voyager")

meuse.grid <- st_as_sf(meuse.grid, coords = c("x", "y"),
                       crs = 28992)
mapview(meuse.grid,  map.types = "CartoDB.Voyager")

v <- variogram(log(zinc) ~ 1, data = meuse)
plot(v)
vgm()
show.vgms(par.strip.text = list(cex = 0.75))





covmodel <- "matern"
sigma2 <- 1

# Plot covariance function
curve(cov.spatial(x, cov.pars = c(sigma2, 1),
                  cov.model = covmodel), lty = 1,
      from = 0, to = 1, ylim = c(0, 1), main = "Matérn",
      xlab = "distance", ylab = "Covariance(distance)")
curve(cov.spatial(x, cov.pars = c(sigma2, 0.2),
                  cov.model = covmodel), lty = 2, add = TRUE)
curve(cov.spatial(x, cov.pars = c(sigma2, 0.01),
                  cov.model = covmodel), lty = 3, add = TRUE)

legend(cex = 1.5, "topright", lty = c(1, 1, 2, 3),
       col = c("white", "black", "black", "black"),
       lwd = 2, bty = "n", inset = .01,
       c(expression(paste(sigma^2, " = 1 ")),
         expression(paste(phi, " = 1")),
         expression(paste(phi, " = 0.2")),
         expression(paste(phi, " = 0.01"))))

meugrid <- cbind(runif(100), runif(100))
sim1 <- grf(100, grid = meugrid,
            cov.model = covmodel, cov.pars = c(sigma2, 1))

erro <- rnorm(100, 0, 0.2)
y <- sim1$data + erro
sim4 <- sim1
sim4$data <- y 

d <- st_as_sf(data.frame(x = sim4$coords[, 1],
                            y = sim4$coords[, 2],
                            value = sim4$data),
                            coords = c("x", "y")
)


ggplot(d) + geom_sf(aes(color = value), size = 2) +
  scale_color_gradient(low = "blue", high = "orange") +
  geom_path(data = data.frame(d$border)) +
  theme_bw()

par(mfrow = c(1, 2))
plot(variog(coords = st_coordinates(d), data = d$value,
            option = "cloud", max.dist = 400))

plot(variog(sim4))

var_teo <- 0.2 + 1(1 - cor())