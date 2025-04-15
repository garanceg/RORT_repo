# RORT_projet

Ce projet correspond à notre travail effectué pour le cours RORT qui consistait à modéliser et résoudre le problème de placement de fonctions virtuelles sur un réseau. 

Nous présentons alors ici le fruit de notre réflexion qui nous a mené à proposer trois approches différentes dont une seule semble donner des résultats satisfaisants (model_3_bis) : 

1. Une modélisation avec un flot sur les arcs dont la reformulation KKT est implémentée dans le fichier model_KKT.jl
2. Une modélisation avec un flot sur les chemins dont l'implémentation de la génération de colonnes se trouve dans le fichier model_3_bis.jl
3. Une modélisation inspirée du problème de la coupe minimale dans un graphe, dont l'implémentation se trouve dans le fichier min_cut.jl