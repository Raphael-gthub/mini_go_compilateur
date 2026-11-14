#!/bin/sh
# Lance mgoc sur tous les programmes de test et compare le code de retour au résultat attendu.
# Usage : ./tests/run_tests.sh [chemin/vers/mgoc.exe]   (par défaut : _build/default/mgoc.exe)
# Le script s'arrête au typage : il ne régénère pas les fichiers .s.

MGOC="${1:-_build/default/mgoc.exe}"
DIR="$(dirname "$0")"
echecs=0

# verifie <code attendu> <fichier> <option de mgoc>
verifie() {
    attendu="$1"; fichier="$2"; option="$3"
    "$MGOC" "$option" "$fichier" > /dev/null 2>&1
    obtenu=$?
    if [ "$obtenu" -eq "$attendu" ]; then
        echo "  ok     $fichier $option"
    else
        echo "  ECHEC  $fichier $option (code $obtenu, attendu $attendu)"
        echecs=$((echecs + 1))
    fi
}

echo "Programmes valides : l'analyse syntaxique et le typage doivent réussir"
for f in "$DIR"/ok/*.go; do verifie 0 "$f" --type-only; done

echo "Erreurs de syntaxe : l'analyse syntaxique doit échouer"
for f in "$DIR"/ko_syntaxe/*.go; do verifie 1 "$f" --parse-only; done

echo "Erreurs de typage : la syntaxe est correcte, le typage doit échouer"
for f in "$DIR"/ko_type/*.go; do verifie 0 "$f" --parse-only; verifie 1 "$f" --type-only; done

if [ "$echecs" -eq 0 ]; then
    echo "Tous les tests passent."
else
    echo "$echecs test(s) en échec."
    exit 1
fi
