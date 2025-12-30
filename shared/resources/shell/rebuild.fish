# Decrypt cache signing key if needed
if test -f "@cacheKeyAgePath@" && test ! -f "@cacheKeyPath@"
  echo "Decrypting cache signing key..."
  if test -f "@ageIdentity@"
    @ageBin@ -d -i "@ageIdentity@" "@cacheKeyAgePath@" > "@cacheKeyPath@"
    if test $status -ne 0
      echo "Failed to decrypt cache key"
      return 1
    end
    chmod 600 "@cacheKeyPath@"
  else
    echo "Warning: Age identity not found at @ageIdentity@, skipping cache key decryption"
  end
end

# Run the rebuild
@nhCommand@
