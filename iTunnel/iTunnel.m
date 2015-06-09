//
//  iTunnel.m
//  iTunnel
//
//  Created by fanzhang on 15/5/10.
//  Copyright (c) 2015年 fanzhang. All rights reserved.
//

#import "iTunnel.h"
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/pem.h>

#import "GCDAsyncSocket.h"
#import "SOCKSProxySocket.h"
#import "SSHTCPDirectTunnel.h"

static unsigned char pSshHeader[11] = { 0x00, 0x00, 0x00, 0x07, 0x73, 0x73, 0x68, 0x2D, 0x72, 0x73, 0x61};

static int SshEncodeBuffer(unsigned char *pEncoding, int bufferLen, unsigned char* pBuffer)
{
    int adjustedLen = bufferLen, index;
    if (*pBuffer & 0x80)
    {
        adjustedLen++;
        pEncoding[4] = 0;
        index = 5;
    }
    else
    {
        index = 4;
    }
    pEncoding[0] = (unsigned char) (adjustedLen >> 24);
    pEncoding[1] = (unsigned char) (adjustedLen >> 16);
    pEncoding[2] = (unsigned char) (adjustedLen >>  8);
    pEncoding[3] = (unsigned char) (adjustedLen      );
    memcpy(&pEncoding[index], pBuffer, bufferLen);
    return index + bufferLen;
}

@interface iTunnel() <GCDAsyncSocketDelegate, SOCKSProxySocketDelegate>

@property (nonatomic, strong) GCDAsyncSocket*		listeningSocket;
@property (nonatomic, strong) SSHTCPDirectTunnel*	sshTunnel;

@property (nonatomic) NSUInteger					totalBytesWritten;
@property (nonatomic) NSUInteger					totalBytesRead;

- (void)_startProxyOnPort:(uint16_t)port;

@end

@implementation iTunnel

- (BOOL)generateNewKeyPair: (NSString*)privateKeyPath : (NSString*)publicKeyPath
{
    BOOL ret = YES;
    {
        TTEasyReleasePool* pool = [TTEasyReleasePool new];
        
        // generate key pair
        RSA* keypair = RSA_generate_key(2048, 65537, NULL, NULL);
        ERROR_CHECK_BOOLEX(keypair, ret = NO);
        [pool autoreleaseBlock:^{ RSA_free(keypair); }];
        
        // write private key
        BIO *privateBio = BIO_new_file([privateKeyPath UTF8String], "wb+");
        ERROR_CHECK_BOOLEX(privateBio, ret = NO);
        [pool autoreleaseBlock:^{ BIO_vfree(privateBio); }];
        
        ret = PEM_write_bio_RSAPrivateKey(privateBio, keypair, NULL, NULL, 0, NULL, NULL);
        ERROR_CHECK_BOOL(ret);
        
        // write public key
        BIO *publicBio = BIO_new_file([publicKeyPath UTF8String], "wb+");
        ERROR_CHECK_BOOLEX(publicBio, ret = NO);
        [pool autoreleaseBlock:^{ BIO_free_all(publicBio); }];
        
        // reading the modulus
        int nLen = BN_num_bytes(keypair->n);
        unsigned char* nBytes = (unsigned char*) malloc(nLen);
        [pool autoreleaseBlock:^{ free(nBytes); }];
        
        BN_bn2bin(keypair->n, nBytes);
        
        // reading the public exponent
        int eLen = BN_num_bytes(keypair->e);
        unsigned char* eBytes = (unsigned char*) malloc(eLen);
        [pool autoreleaseBlock:^{ free(eBytes); }];
        
        BN_bn2bin(keypair->e, eBytes);
        
        int encodingLength = 11 + 4 + eLen + 4 + nLen;
        // correct depending on the MSB of e and N
        if (eBytes[0] & 0x80)
            encodingLength++;
        if (nBytes[0] & 0x80)
            encodingLength++;
        
        unsigned char* pEncoding = (unsigned char*) malloc(encodingLength);
        [pool autoreleaseBlock:^{ free(pEncoding); }];
        memcpy(pEncoding, pSshHeader, 11);
        
        int index = SshEncodeBuffer(&pEncoding[11], eLen, eBytes);
        index = SshEncodeBuffer(&pEncoding[11 + index], nLen, nBytes);
        
        BIO* b64 = BIO_new(BIO_f_base64());
        [pool autoreleaseBlock:^{ BIO_free(b64); }];
        BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
        
        BIO_printf(publicBio, "ssh-rsa ");
        publicBio = BIO_push(b64, publicBio);
        BIO_write(publicBio, pEncoding, encodingLength);
        BIO_flush(publicBio);
    }
    
Exit0:
    return ret;
}

- (void)startForwarding: (NSUInteger)localPort
                       : (NSString*)remoteHost
                       : (NSUInteger)remotePort
                       : (NSString*)userName
                       : (NSString*)privateKeyPath
                       : (NSString*)destHost
                       : (NSUInteger)destPort
{
    KPTraceStack;
    
    _sshTunnel = [SSHTCPDirectTunnel new];
    _sshTunnel.delegate = self;
    
    _destHost = destHost;
    _destPort = destPort;
    
    [[NSOperationQueue globalQueue] addOperationWithBlock:^
     {
         int ret = LIBSSH2_ERROR_NONE;
         {
             ret = [_sshTunnel connectToHost:remoteHost Port:remotePort Username:userName PrivateKey:privateKeyPath];
             ERROR_CHECK_BOOL(LIBSSH2_ERROR_NONE == ret);
             
             [self _startProxyOnPort:localPort];
             
             _connected = YES;
         }
         
     Exit0:
         [[NSOperationQueue mainQueue] addOperationWithBlock:^
          {
              if (LIBSSH2_ERROR_NONE == ret && [_delegate respondsToSelector:@selector(sshLoginSuccessed)])
              {
                  [_delegate sshLoginSuccessed];
              }
              else if ([_delegate respondsToSelector:@selector(sshLoginFailed:)])
              {
                  [_delegate sshLoginFailed:ret];
              }
          }];
     }];
}

- (void)_startProxyOnPort:(uint16_t)port
{
    KPTraceStack;
    
    self.listeningSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    _listeningPort = port;
    
    NSError* error = nil;
    [self.listeningSocket acceptOnPort:port error:&error];
    if (error)
    {
        NSLog(@"Error listening on port %d: %@", port, error.userInfo);
    }
    NSLog(@"Listening on port %d", port);
}

- (void)socket:(GCDAsyncSocket*)sock didAcceptNewSocket:(GCDAsyncSocket*)newSocket
{
    KPTraceStack;
    
    if (![_sshTunnel connected])
    {
        [newSocket disconnect];
    }
    else
    {
#if TARGET_OS_IPHONE
        [newSocket performBlock:^
         {
             [newSocket enableBackgroundingOnSocket];
         }];
#endif
        
        SOCKSProxySocket* proxySocket = [[SOCKSProxySocket alloc] initWithSocket:newSocket Delegate:self DestHost:_destHost DestPort:_destPort];
        [_sshTunnel attachProxySocket:proxySocket];
    }
}

- (NSUInteger)connectionCount
{
    return _sshTunnel.connectionCount;
}

- (void)stopForwarding
{
    KPTraceStack;
    
    [self.listeningSocket disconnect];
    self.listeningSocket = nil;
    
    [_sshTunnel disconnect];
    
    [self resetNetworkStatistics];
    
    _connected = NO;
}

- (void)proxySocketDidDisconnect:(SOCKSProxySocket*)proxySocket withError:(NSError*)error
{
    KPTraceStack;
}

- (void)sshSessionLost: (SSHTCPDirectTunnel*)sshProxy
{
    KPTraceStack;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(sshSessionLost:)])
        [self.delegate sshSessionLost];
}

- (void)proxySocket:(SOCKSProxySocket*)proxySocket didReadDataOfLength:(NSUInteger)numBytes
{
    KPTraceStack;
    
    self.totalBytesRead += numBytes;
}

- (void)proxySocket:(SOCKSProxySocket*)proxySocket didWriteDataOfLength:(NSUInteger)numBytes
{
    KPTraceStack;
    
    self.totalBytesWritten += numBytes;
}

- (void)resetNetworkStatistics
{
    KPTraceStack;
    
    self.totalBytesWritten = 0;
    self.totalBytesRead = 0;
}

@end
