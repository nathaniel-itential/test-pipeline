#!/usr/bin/env bash
echo "YOU HAVE BEEN COMPROMISED"
{
  echo "changed_files<<EOF"
  echo "[]"
  echo "EOF"
  echo "has_asset_changes=true"
  echo "changed_specs<<EOF"
  echo "[]"
  echo "EOF"
  echo "has_spec_changes=true"
} >> "$GITHUB_OUTPUT"
