# Prismarine name and logo policy

The Prismarine **source code** is free software under the GNU GPL v3 (see
[LICENSE](LICENSE)). You can use, study, change and share it under those terms.

The **name "Prismarine" as used for this launcher** and the **Prismarine logos**
(`assets/logos/`) are a different matter. They identify the official project by
Fi3w0, and the GPL does not grant rights to them. The logos are artwork licensed
under [CC BY-NC-ND 4.0](assets/logos/LICENSE) (credit Fi3w0, non-commercial, no
modifications). That license does not cover trademark rights, so this policy adds
how the name and logos may be used to identify software.

## Always fine

- Saying that something works with, is built for, or is based on Prismarine,
  for example "a theme for Prismarine" or "forked from Prismarine".
- Writing about, reviewing, streaming or teaching Prismarine, using the name and
  unmodified logos to refer to it.
- Packaging an official release for a Linux distribution, Flatpak or similar,
  keeping the name and logos, as long as changes are limited to what packaging
  needs (paths, build flags, dependency patches) and are documented.
- Building and running your own modified copy for yourself.

## Needs a new name and logo

If you **distribute a modified version** (a fork), you must:

1. Give it a different name that is not confusingly similar to "Prismarine".
2. Replace everything in `assets/logos/` and the app icon with your own artwork.
3. Change the window title, application ID (`io.github.fi3w0.Prismarine` in
   `packaging/linux/` and `setDesktopFileName`) and About page so
   users can tell it apart from the official app.
4. Keep the copyright notices, `NOTICE` and `LICENSE`, and state that your
   version is based on Prismarine by Fi3w0 with a link to the original.
   The GPL already requires keeping the notices; the credit line is part of
   using the name only as a reference.

## Not allowed without permission

- Selling or publishing anything under the Prismarine name or logos, other than
  the cases above.
- Using the name or logos to suggest that a product, fork, server, modpack or
  service is official or endorsed.
- Domain names, app store listings or social accounts that could be mistaken
  for the official project.

## Asking

If you are unsure, or want permission for something not listed here, open an
issue or contact Fi3w0 through <https://github.com/Fi3w0>. Permission is usually
easy to get for community projects that credit the original.
