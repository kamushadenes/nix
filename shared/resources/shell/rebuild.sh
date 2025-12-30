# Decrypt cache signing key if needed
if test -f "@cacheKeyAgePath@" && test ! -f "@cacheKeyPath@"; then
  echo "Decrypting cache signing key..."
  if test -f "@ageIdentity@"; then
    @ageBin@ -d -i "@ageIdentity@" "@cacheKeyAgePath@" > "@cacheKeyPath@"
    if test $? -ne 0; then
      echo "Failed to decrypt cache key"
      return 1
    fi
    chmod 600 "@cacheKeyPath@"
  else
    echo "Warning: Age identity not found at @ageIdentity@, skipping cache key decryption"
  fi
fi

# Run the rebuild
@nhCommand@
