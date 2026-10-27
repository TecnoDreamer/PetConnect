import '../../../core/utils/legacy_public_id.dart';
import 'pet.dart';

/// `publicId` que o QR code do pet codifica hoje (RF16/RF19).
///
/// [Pet.qrPublicId] vem preenchido pela API (`USE_API_PETS=true`) e, no
/// modo Firestore (o padrão), depois que o tutor regenera o QR. Sem ele,
/// calculamos o mesmo `publicId` determinístico que a migração
/// (`LegacyMigrationService`) grava para esse pet — usar [Pet.id] direto
/// faria o QR apontar para um valor que o endpoint público nunca reconhece
/// (causa raiz em docs/fixes/qr-public-pet-not-found.md).
String publicIdDoQr(Pet pet) => pet.qrPublicId ?? legacyPublicIdFor(pet.id);

/// URL que o QR code de um pet codifica (RF16), consumida pela página
/// pública em `pet-connect-c53f1.web.app` (Firebase Hosting, FASE 9).
String publicPetUrl(Pet pet) =>
    'https://pet-connect-c53f1.web.app/pet/${publicIdDoQr(pet)}';
