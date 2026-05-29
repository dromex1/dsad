# GitHub Actions IPA build

Ten projekt ma workflow `.github/workflows/build-ipa.yml`, który na macOS:

1. pobiera repo razem z Git LFS,
2. instaluje Godot `4.6-stable` i export templates,
3. importuje projekt,
4. eksportuje projekt Xcode z presetu `iOS`,
5. buduje unsigned `.app` dla `iphoneos`,
6. pakuje `WiejskiKaskader-Sideloadly.ipa` jako artifact.

## Wymagane przed pierwszym push

Repo zawiera assety większe niż limit GitHub 100 MB. Muszą być zapisane w Git LFS:

```bash
git lfs install
git lfs track "*.glb" "*.gltf" "*.png" "*.jpg" "*.jpeg" "*.webp" "*.mp3" "*.wav" "*.ogg" "*.otf" "*.ttf" "*.zip" "*.gz" "*.unitypackage"
git add .gitattributes
git add .
git commit -m "Prepare iOS IPA GitHub Actions build"
git push
```

Jeżeli duże pliki były już wcześniej commitowane bez LFS, sam plik `.gitattributes` nie wystarczy. Trzeba przenieść historię do LFS albo utworzyć świeże repo i dodać pliki dopiero po `git lfs track`.

## Pobranie IPA

Po wejściu w `Actions -> Build IPA for Sideloadly -> Run workflow` pobierz artifact `WiejskiKaskader-iPhone-Sideloadly`. Plik `.ipa` jest unsigned i przeznaczony do podpisania przez Sideloadly.
