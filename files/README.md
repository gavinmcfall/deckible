# Local Installation Files

This directory is for local files when not using a private overlay repo.

**Recommended**: Use a private overlay repo instead (see main README.md).

## Structure

```
files/
├── flatpaks/      # .flatpak bundle files
├── appimages/     # .AppImage or .desktop files
└── README.md
```

## Usage

Place files here if you're not using a private overlay repository.
The playbook will check both `private/files/` and `files/` for local installations.

**Note**: This directory is gitignored (except README and .gitkeep files).
For portable configurations, use a private overlay repo instead.
