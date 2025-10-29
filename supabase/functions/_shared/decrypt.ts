import { decode } from 'https://deno.land/std@0.208.0/encoding/base64.ts';

// Imports the raw key string
async function importKey(keyString: string) {
  const keyData = atob(keyString);
  const keyBuffer = new Uint8Array(keyData.length);
  for (let i = 0; i < keyData.length; i++) {
    keyBuffer[i] = keyData.charCodeAt(i);
  }
  return await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'AES-GCM' },
    false,
    ['encrypt', 'decrypt'] // Add 'decrypt' permission
  );
}

// Decrypts the "iv:ciphertext" string
export async function decrypt(encryptedString: string, keyString: string): Promise<string> {
  const parts = encryptedString.split(':');
  if (parts.length !== 2) {
    throw new Error('Invalid encrypted string format. Expected "iv:ciphertext".');
  }

  const [ivString, cipherString] = parts;

  const key = await importKey(keyString);
  const iv = decode(ivString);
  const ciphertext = decode(cipherString);

  const decryptedBuffer = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: iv },
    key,
    ciphertext
  );

  return new TextDecoder().decode(decryptedBuffer);
}