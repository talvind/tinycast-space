# Обновление форка

Как обновить `talvind/tinycast-space` из `sermelipharo/tinycast-space` и заново собрать
`Tinycast Dev.app`, не потеряв настройку прокси.

## Что важно знать

- `sermelipharo/main` — **генерируемая ветка**. Её пересобирают и force-push-ят при каждом
  обновлении upstream. Поэтому не делай `git merge upstream/main` в долгоживущую ветку: история
  переписывается, и конфликтов будет больше, чем нужно.
- Наши изменения прокси лежат двумя слоями:
  - обычный коммит с кодом;
  - `.space/patches/0031-proxy-settings.patch` — переносимый патч для patch-системы форка.
- Для личной сборки проще всего: взять свежий `upstream/main`, применить патч `0031` и собрать.
- `sermelipharo/main` уже содержит его патчи `0001…0030`. Патч `0031` рассчитан именно на такое
  состояние, поэтому применяется поверх `upstream/main`, а не поверх чистого upstream.

## 0. Проверить remotes

```sh
cd ~/MyProjects/tinycast/space
git remote -v
```

Должно быть:

```text
origin    https://github.com/talvind/tinycast-space.git
upstream  https://github.com/sermelipharo/tinycast-space.git
```

Если `upstream` нет:

```sh
git remote add upstream https://github.com/sermelipharo/tinycast-space.git
```

## 1. Обновить upstream и создать ветку синхронизации

Рабочее дерево должно быть чистым. Если есть незакоммиченные изменения — сначала закоммить или
спрячь их.

```sh
git status
git fetch upstream main --prune
git switch -c "sync/upstream-$(date +%Y%m%d)" upstream/main
```

## 2. Применить патч прокси

Достаём сохранённый патч из ветки `feature/proxy-settings`:

```sh
git show feature/proxy-settings:.space/patches/0031-proxy-settings.patch \
  > /tmp/0031-proxy-settings.patch
```

Применяем:

```sh
git apply --3way --whitespace=nowarn /tmp/0031-proxy-settings.patch
```

Если появились конфликты:

```sh
git status
# отредактировать файлы с маркерами <<<<<<< ======= >>>>>>>
git add <исправленные файлы>
```

`git apply` не имеет `--continue`: после разрешения конфликтов просто добавь файлы в индекс.

## 3. Перегенерировать Xcode-проект

Патч добавляет новые Swift-файлы, поэтому проект нужно пересобрать через XcodeGen:

```sh
xcodegen generate
```

## 4. Собрать и запустить

Debug-сборка:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Tinycast.xcodeproj \
  -scheme Tinycast \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Запуск:

```sh
open "build/DerivedData/Build/Products/Debug/Tinycast Dev.app"
```

Если macOS блокирует запуск:

```sh
xattr -dr com.apple.quarantine "build/DerivedData/Build/Products/Debug/Tinycast Dev.app"
open "build/DerivedData/Build/Products/Debug/Tinycast Dev.app"
```

Release-сборка — то же самое, только:

```sh
-configuration Release
```

и путь будет `build/DerivedData/Build/Products/Release/Tinycast.app`.

## 5. Прогнать тесты

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/run-tests.sh
```

На момент переноса патча в форке уже падал `form-input-test` — он падает и на чистом
`sermelipharo/main`, без наших изменений. Если после обновления падает только он, это не регрессия
прокси. Остальные harness-ы должны проходить.

## 6. Закоммитить и запушить ветку

```sh
git add -A
git commit -m "Sync sermelipharo main and keep proxy patch"
git push -u origin "HEAD"
```

Если хочешь сохранить и сам `.space`-патч в ветке синхронизации, перенеси коммит с `.space`
из `feature/proxy-settings`:

```sh
git cherry-pick 247a584a
```

Если в `.space/README.md` будет конфликт — оставь строку `0031` и строки, пришедшие из нового
`upstream/main`.

## 7. Обновить main (необязательно)

Если в `main` твоего форка нет других собственных коммитов, можно сделать `main` равным
синхронизированной ветке:

```sh
git switch main
git reset --hard sync/upstream-YYYYMMDD
git push --force-with-lease origin main
```

Подставь фактическое имя ветки. Если в `main` есть другие твои изменения — не делай
`reset --hard`, а влей ветку через merge или оставь обновление отдельной веткой.

## Если патч перестал применяться

Это нормально, если `sermelipharo` изменил те же файлы. Порядок:

1. Применить патч с `--3way`.
2. Разрешить конфликты вручную.
3. Собрать и прогнать тесты.
4. Пересобрать сам патч уже против нового `upstream/main`:

```sh
git diff --no-color --binary --full-index upstream/main..HEAD -- . \
  ':!Tinycast.xcodeproj' \
  ':!Tinycast/Resources/RaycastRuntime.generated.js' \
  ':!.space' \
  > .space/patches/0031-proxy-settings.patch
```

5. Закоммитить обновлённый патч.

## Откат

Если после обновления что-то сломалось, вернись на сохранённую ветку:

```sh
git switch feature/proxy-settings
```

или создай новую ветку от последнего рабочего состояния:

```sh
git switch -c rollback/proxy-$(date +%Y%m%d) 247a584a
```

## Быстрая шпаргалка

```sh
cd ~/MyProjects/tinycast/space
git fetch upstream main
git switch -c "sync/upstream-$(date +%Y%m%d)" upstream/main
git show feature/proxy-settings:.space/patches/0031-proxy-settings.patch > /tmp/0031.patch
git apply --3way /tmp/0031.patch
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
open "build/DerivedData/Build/Products/Debug/Tinycast Dev.app"
```
