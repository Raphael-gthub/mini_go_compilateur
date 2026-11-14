# Petit Go : un compilateur vers MIPS écrit en OCaml

Compilateur pour « Petit Go », un sous-ensemble du langage Go : analyse lexicale, analyse syntaxique, vérification des types et génération de code assembleur MIPS.
Projet du cours de compilation (L3, double licence informatique-mathématiques, Université Paris-Saclay, automne 2025), réalisé en binôme.

Le programme `mgoc` lit un fichier `.go` et écrit à côté un fichier `.s`, exécutable dans un simulateur MIPS comme MARS ou SPIM.

```go
package main;
import "fmt";

func abso(x int) int {
  if x < 0 {
    return -x;
  } else {
    return x;
  }
};

func main() {
  var a int;
  a = -3;
  var b int;
  b = abso(a);
  fmt.Print(b);
};
```

```
$ ./mgoc.exe tests/ok/abs.go        # écrit tests/ok/abs.s
$ spim -file tests/ok/abs.s
3
```

Une erreur dans le programme source est signalée avec sa position :

```
$ ./mgoc.exe tests/ko_type/ko_assign_type.go
File "tests/ko_type/ko_assign_type.go", line 7, characters 2-10:
error: expected int, got bool
```

## Le langage reconnu

- Un fichier commence par `package main`, suivi éventuellement de `import "fmt"`.
- Déclarations de structures (`type T struct { ... }`) et de fonctions, avec plusieurs valeurs de retour possibles.
- Types `int`, `bool`, `string` et pointeurs vers une structure (`*T`), allocation avec `new(T)`.
- Instructions : déclarations `var` et `:=`, affectations multiples, `++` et `--`, `if` / `else if` / `else`, blocs, `return`, et les formes de `for` de Go (boucle infinie, condition seule, trois clauses).
- Expressions : entiers décimaux et hexadécimaux, chaînes avec séquences d'échappement, booléens, `nil`, accès aux champs, appels de fonctions, `fmt.Print`, opérateurs arithmétiques, de comparaison et logiques avec les priorités de Go.
- Commentaires `//` et `/* ... */`.

## Les étapes de la compilation

| Fichier | Rôle |
| --- | --- |
| `mgolexer.mll` | Analyse lexicale avec ocamllex. Le lexeur insère lui-même les points-virgules en fin de ligne, comme le fait Go : après un identifiant, un littéral, `return`, `++`, `--`, `)` ou `}`. |
| `mgoparser.mly` | Grammaire Menhir qui construit l'arbre de syntaxe. Les boucles `for` à trois clauses sont traduites en boucles à condition simple dès cette étape. |
| `typechecker.ml` | Vérification des types avec trois environnements (variables, fonctions, structures) : types des expressions, cibles d'affectation, nombre de valeurs dans les affectations et les `return`, fonctions à plusieurs résultats, déclarations en double, usage de `fmt.Print` sans import. |
| `compile.ml` | Génération du code MIPS, décrite ci-dessous. |
| `mips.ml` | Écriture des instructions MIPS. |
| `mgoast.ml` | Définition de l'arbre de syntaxe abstraite. |
| `mgoc.ml` | Programme principal : lecture des options, enchaînement des étapes, affichage des erreurs localisées. |

Le projet part d'un squelette fourni par l'équipe enseignante : l'arbre de syntaxe, le programme principal et la base de `mips.ml`. Le lexeur, la grammaire, le typeur et le générateur de code sont notre travail.

## La génération de code

- **Expressions.** Le résultat d'une expression est toujours placé dans le registre `$t0`. Pour une opération binaire, l'opérande droit est calculé puis empilé, l'opérande gauche est calculé, et le résultat combine les deux.
- **Fonctions.** L'appelant empile les arguments. La fonction appelée sauvegarde `$ra` et `$fp`, réserve la place de ses variables locales sous `$fp` et lit ses paramètres au-dessus. Une première passe sur le corps de la fonction attribue un emplacement à chaque variable locale. Les appels imbriqués et la récursivité fonctionnent.
- **Structures.** Une structure est allouée sur le tas par l'appel système `sbrk`, avec un mot de 4 octets par champ. `a.x` se traduit par une lecture à l'adresse de `a` décalée de la position du champ.
- **Plusieurs valeurs de retour.** La fonction alloue un n-uplet sur le tas et renvoie son adresse ; `x, y := f()` va y lire chaque valeur.
- **Contrôle.** `if` et `for` sont traduits en étiquettes et en branchements.
- **Affichage.** Les chaînes littérales sont placées dans la section `.data` ; `fmt.Print` utilise les appels système d'affichage d'un entier et d'une chaîne.

## Compiler et tester

Il faut OCaml, dune (3.13 ou plus récent) et menhir :

```bash
opam install dune menhir
dune build
./tests/run_tests.sh
```

`dune build` crée `_build/default/mgoc.exe` et en place une copie à la racine. Le script lance le compilateur sur les programmes de `tests/` et compare le code de retour au résultat attendu :

| Dossier | Contenu | Résultat attendu |
| --- | --- | --- |
| `tests/ok/` | 13 programmes valides | analyse syntaxique et typage réussis |
| `tests/ko_syntaxe/` | 6 programmes avec une erreur de syntaxe | erreur signalée, code de retour 1 |
| `tests/ko_type/` | 5 programmes syntaxiquement corrects mais mal typés | erreur de typage signalée, code de retour 1 |

Options de `mgoc` : `--parse-only` s'arrête après l'analyse syntaxique, `--type-only` après le typage ; sans option, le fichier `.s` est écrit. Le `Makefile` propose aussi `make testoktype`, `make testok`, `make testkot` et `make testkos`.

Le dépôt contient le code MIPS produit pour neuf programmes de `tests/ok/`, avec la sortie obtenue à l'exécution :

| Programme | Ce qu'il exerce | Sortie |
| --- | --- | --- |
| `min.go` | affichage d'une constante | `42` |
| `arith.go` | priorités et parenthèses | `42` |
| `var.go` | variables locales | `42` |
| `abs.go` | appel de fonction, `if` / `else` | `3` |
| `instr.go` | boucle `for`, modulo, division (exponentiation rapide) | `512` |
| `precedence.go` | opérateurs logiques et unaires | `5`, `9`, `1`, `0`, `-9` |
| `point.go` | structures et `new` | `10` |
| `print.go` | entiers, booléen, chaîne | `1`, `2`, `1`, `hello` |
| `div.go` | fonctions à deux résultats, récursivité, structures | `7` et `3` (45 divisé par 6) |

## Limites connues

- `fmt.Print` n'affiche pas tout : un booléen s'affiche `1` ou `0`, une chaîne ne s'affiche que si elle est écrite directement dans l'appel, et il faut passer par une variable pour afficher un champ de structure ou les résultats d'une fonction qui en renvoie plusieurs.
- La mémoire allouée pour les structures et les n-uplets n'est jamais libérée.
- La position d'un champ est cherchée par son nom seul, ce qui est ambigu si deux structures ont un champ de même nom à des positions différentes.
- Les opérateurs `&&` et `||` évaluent toujours leurs deux opérandes.
- Deux variables de même nom dans une même fonction partagent le même emplacement, même si elles sont déclarées dans des blocs différents.
- Les entiers sont compilés sur 32 bits.
- Le compilateur ne vérifie pas qu'une fonction `main` existe, ni qu'un pointeur a été alloué avant d'être utilisé : `tests/ok/test.go` et `tests/ok/struct.go` passent le typage mais ne donnent pas un programme exécutable.
- Les variables locales inutilisées ne sont pas signalées.

Le rapport rendu avec le projet est dans [`docs/rapport.pdf`](docs/rapport.pdf).

## Auteurs

Raphaël Dubach et Kyrylo Hrynevych.

